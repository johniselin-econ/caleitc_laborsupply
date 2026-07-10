# =============================================================================
# File:    diagnose_sim2_residual.R
# Purpose: Diagnose the residual sim-2 cell divergence (303 fed / 117 state
#          cells, job 17098348) that survives the golden-sage substitution.
#
#          Hypothesis: taxsimlocal35.ado writes TAXSIM inputs with `outsheet`,
#          which uses display formats — the money vars are doubles at the
#          default %10.0g (~9 significant digits). Sim-2's cpi reflation
#          creates long decimal tails that Stata truncated but the R port
#          sends at full precision; near TAXSIM's internal discretization
#          (the $50 EITC table brackets) the ~1e-4 input difference flips a
#          row's EITC by dollars, and small cells then miss the 2-cent
#          tolerance.
#
#          Uses the stage8b dump (code/hpc/stage8_txpydump.do):
#            data/interim/sim2_txpydata_golden.raw — byte-exact replica of
#              what taxsimlocal35.ado outsheeted in the original run
#            data/interim/sim2_stack_meta.csv — cell keys + weight by the
#              stacked taxsimid
#
#          Part 1: feed the golden bytes through taxsim35.exe, collapse to
#                  cells, compare to the working file. 0 mismatches proves
#                  everything except input formatting is already exact.
#          Part 2: rebuild the R compat stack (golden sage) and compare it
#                  row-by-row to the golden input file — ids/demographics
#                  must be identical; money diffs must be truncation-scale.
#          Part 3: run the full-precision stack, diff row-level EITC against
#                  the golden-input run, characterize the flipped rows
#                  ($50-bracket proximity), and map them to the failing cells.
#
# Usage:   Rscript code/validate/diagnose_sim2_residual.R   (sbatch; ~50 GB)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
source(file.path("code", "lib", "qc_assignment.R"))
source(file.path("code", "lib", "clean_steps.R"))
source(file.path("code", "lib", "taxsim.R"))

suppressPackageStartupMessages(library(haven))

exe <- path.expand("~/ado/plus/t/taxsim35.exe")
cpi_by_year <- lapply(params$prices$cpi99, float_round)

money_vars <- c("pwages", "swages", "psemp", "ssemp", "intrec", "otherprop")
int_vars   <- c("year", "state", "mstat", "page", "sage", "depx")

# ---- Part 1: golden bytes -> taxsim35 -> cells -> working file --------------

message("===== Part 1: golden-input run =====")
infile_g  <- path_data("interim", "sim2_txpydata_golden.raw")
outfile_g <- file.path(tempdir(), "results_golden.raw")
status <- system2(exe, stdin = infile_g, stdout = outfile_g, stderr = FALSE)
if (status != 0) stop("taxsim35.exe exited with status ", status)

res_g <- suppressWarnings(
  read_csv(outfile_g, show_col_types = FALSE, guess_max = 1e6,
           col_select = c("taxsimid", "v25", "v39"))
) |>
  mutate(taxsimid = suppressWarnings(as.numeric(taxsimid))) |>
  filter(!is.na(taxsimid)) |>
  rename(gfed = v25, gst = v39)
message("golden-input run returned ", nrow(res_g), " rows")

meta <- read_csv(path_data("interim", "sim2_stack_meta.csv"),
                 show_col_types = FALSE)
stopifnot(nrow(meta) == nrow(res_g))

cells_golden <- meta |>
  left_join(res_g, by = "taxsimid") |>
  group_by(year, state_soi = state, female, qc_ct = depx, mstat,
           education, age_bracket) |>
  summarise(
    sim2_cellwt  = n(),
    sim2_fedeitc = weighted.mean(gfed, weight),
    sim2_steitc  = weighted.mean(gst, weight),
    .groups = "drop"
  )

golden_cells <- read_dta(
  path_data("final", "acs_working_file.dta"),
  col_select = c(year, state_soi, female, qc_ct, mstat, education,
                 age_bracket, taxsim_sim2_fedeitc, taxsim_sim2_steitc,
                 taxsim_sim2_wt)
) |>
  zap_labels() |>
  filter(!is.na(taxsim_sim2_fedeitc)) |>
  distinct()
message("Stata cells observed in working file: ", nrow(golden_cells))

compare_cells <- function(cells_r, label) {
  cmp <- golden_cells |>
    left_join(cells_r, by = c("year", "state_soi", "female", "qc_ct",
                              "mstat", "education", "age_bracket"))
  n_unmatched <- sum(is.na(cmp$sim2_fedeitc))
  bad <- cmp |>
    mutate(
      d_fed = abs(taxsim_sim2_fedeitc - sim2_fedeitc) >
        pmax(abs(taxsim_sim2_fedeitc) * 1e-5, 2e-2),
      d_st  = abs(taxsim_sim2_steitc - sim2_steitc) >
        pmax(abs(taxsim_sim2_steitc) * 1e-5, 2e-2),
      d_wt  = taxsim_sim2_wt != sim2_cellwt
    )
  n_bad <- colSums(bad[, c("d_fed", "d_st", "d_wt")], na.rm = TRUE)
  message("[", label, "] unmatched: ", n_unmatched,
          "; d_fed: ", n_bad["d_fed"], "; d_st: ", n_bad["d_st"],
          "; d_wt: ", n_bad["d_wt"])
  bad |> filter(is.na(sim2_fedeitc) | d_fed | d_st | d_wt)
}

fails_golden <- compare_cells(cells_golden, "golden bytes")

# ---- Part 2: R compat stack vs golden input file, row by row ----------------

message("\n===== Part 2: row-level input comparison =====")
base2014 <- taxsim_inputs(readRDS(path_data("interim", "acs_2014_clean_r.rds"))) |>
  filter(primary_filer == 1)
golden_in <- read_csv(path_data("interim", "sim2_inputs_golden_2014.csv"),
                      show_col_types = FALSE)
base_compat <- base2014 |>
  select(-sage) |>
  inner_join(golden_in |> select(serial, pernum, sage),
             by = c("serial", "pernum"))
stopifnot(nrow(base_compat) == nrow(base2014))

base14 <- base_compat |>
  select(taxsimid, state, mstat, depx, page, sage, pwages, swages,
         psemp, ssemp, intrec, otherprop,
         cpi99, education, age_bracket, female, weight)
stacked_r <- bind_rows(lapply(2010:2019, function(y) {
  base14 |>
    mutate(across(dplyr::all_of(money_vars),
                  ~ .x * (cpi_by_year[[as.character(y)]] / cpi99)),
           year = y)
})) |>
  arrange(year, taxsimid) |>
  mutate(taxsimid = row_number())

txpy_g <- read_csv(infile_g, show_col_types = FALSE, guess_max = 1e6)
names(txpy_g) <- ifelse(names(txpy_g) == "taxsimid", names(txpy_g),
                        paste0(names(txpy_g), "_g"))
stopifnot(nrow(txpy_g) == nrow(stacked_r))

cmp <- stacked_r |> inner_join(txpy_g, by = "taxsimid")
stopifnot(nrow(cmp) == nrow(stacked_r))

for (v in int_vars) {
  n_bad <- sum(cmp[[v]] != cmp[[paste0(v, "_g")]])
  if (n_bad > 0) stop("row-alignment failure on ", v, ": ", n_bad, " rows")
  message("  OK identical ", v)
}

diff_summary <- lapply(money_vars, function(v) {
  d <- abs(cmp[[v]] - cmp[[paste0(v, "_g")]])
  tibble(var = v,
         n_diff   = sum(d > 0),
         max_abs  = max(d),
         max_rel  = max(ifelse(cmp[[v]] != 0, d / abs(cmp[[v]]), 0)))
}) |> bind_rows()
message("money-var differences (R full precision vs Stata outsheet bytes):")
print(diff_summary)

# ---- Part 3: row-level EITC flips from the formatting difference ------------

message("\n===== Part 3: full-precision run and flip analysis =====")
res_r <- run_taxsim35(stacked_r |> select(dplyr::all_of(TAXSIM_VARS))) |>
  select(taxsimid, rfed = v25, rst = v39)

rowcmp <- res_g |>
  inner_join(res_r, by = "taxsimid") |>
  filter(abs(gfed - rfed) > 0.005 | abs(gst - rst) > 0.005)
message("rows with EITC differing between golden bytes and full precision: ",
        nrow(rowcmp))

flips <- rowcmp |>
  inner_join(cmp, by = "taxsimid") |>
  mutate(
    earned   = pwages + swages + psemp + ssemp,
    earned_g = pwages_g + swages_g + psemp_g + ssemp_g,
    # distance to the nearest $50 EITC-table bracket edge
    br_dist   = pmin(earned %% 50, 50 - earned %% 50),
    br_dist_g = pmin(earned_g %% 50, 50 - earned_g %% 50)
  )
if (nrow(flips) > 0) {
  message("flips by year:")
  print(flips |> count(year))
  message("flip magnitude and $50-bracket proximity (first 15):")
  print(flips |>
          select(taxsimid, year, depx, mstat, gfed, rfed, gst, rst,
                 earned, earned_g, br_dist, br_dist_g) |> head(15), n = 15)
  message("share of flipped rows within $0.01 of a $50 bracket edge: ",
          round(mean(pmin(flips$br_dist, flips$br_dist_g) < 0.01), 3))
}

# cells touched by flips vs cells failing under full precision
cells_r <- stacked_r |>
  left_join(res_r, by = "taxsimid") |>
  group_by(year, state_soi = state, female, qc_ct = depx, mstat,
           education, age_bracket) |>
  summarise(
    sim2_cellwt  = n(),
    sim2_fedeitc = weighted.mean(rfed, weight),
    sim2_steitc  = weighted.mean(rst, weight),
    .groups = "drop"
  )
fails_r <- compare_cells(cells_r, "full precision (recheck of job 17098348)")

flip_cells <- flips |>
  distinct(year, state_soi = state, female, qc_ct = depx, mstat,
           education, age_bracket)
n_explained <- fails_r |>
  semi_join(flip_cells, by = c("year", "state_soi", "female", "qc_ct",
                               "mstat", "education", "age_bracket")) |>
  nrow()
message("failing cells under full precision: ", nrow(fails_r),
        "; of these containing a flipped row: ", n_explained)

saveRDS(list(diff_summary = diff_summary, flips = flips,
             fails_golden = fails_golden, fails_r = fails_r,
             flip_cells = flip_cells),
        path_data("interim", "diag_sim2_residual.rds"))

# ---- Verdict ----------------------------------------------------------------

if (nrow(fails_golden) == 0) {
  message("\n===== DIAGNOSIS CONFIRMED =====")
  message("Feeding Stata's exact outsheet bytes through taxsim35.exe ",
          "reproduces ALL ", nrow(golden_cells), " working-file cells. ",
          "The residual divergence is outsheet's %10.0g display-format ",
          "truncation of the cpi-reflated money inputs, not a logic bug.")
} else {
  message("\n===== DIAGNOSIS INCOMPLETE =====")
  message(nrow(fails_golden), " cells still mismatch even with byte-exact ",
          "golden inputs — a further divergence exists downstream ",
          "(collapse/merge logic). Inspect fails_golden in ",
          "data/interim/diag_sim2_residual.rds")
}
