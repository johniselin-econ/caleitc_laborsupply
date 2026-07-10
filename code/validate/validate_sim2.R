# =============================================================================
# File:    validate_sim2.R
# Purpose: Validate the TAXSIM Simulation 2 port (cell-based simulated
#          instrument) against the Stata working file, isolating the two
#          known Stata-side artifacts (see the DELIBERATE NON-PORTS note in
#          code/lib/taxsim.R):
#
#          1. sage contamination, and its NON-DETERMINISM — the Stata
#             pipeline regenerates the sim-2 inputs on the COMBINED
#             all-years file (01_clean_data.do:903-981), but hh_id is a
#             per-year dense rank, so `bysort hh_id unit_id (pernum)` pools
#             up to 14 unrelated households and the regenerated sage (spouse
#             age) picks up other years' rows. Worse, the tie order among
#             colliding (hh_id, unit_id, pernum) rows is set by an UNSTABLE
#             sort, so where the extremal rows carry different ages the
#             realized sage varies across runs: the original run's
#             realization differs from the golden dumps' (which agree with
#             each other) on 374 married cells and is unrecoverable (the
#             merge-back re-sorted the working file, erasing the tie order).
#             Diagnosed by diagnose_sim2_residual.R + stage8_txpydump.do
#             (jobs 17113329/17113330): byte-exact golden inputs reproduce
#             every cell except those, and all 374 are married (mstat = 2) —
#             childless cells through the federal age test, with-kids cells
#             through state-EITC age dependence.
#          2. outsheet %10.0g truncation — taxsimlocal35.ado writes the
#             TAXSIM input file with `outsheet`, which uses display formats;
#             the money vars are doubles at the default %10.0g, so the
#             cpi-reflated values reached taxsim35.exe rounded to ~8-9
#             significant digits. Flips single rows' EITC near TAXSIM's $50
#             brackets (5,362 of 16M rows) but never moves a cell mean past
#             the comparison tolerance — measurable, immaterial.
#
#          Part A: joins R base inputs to the Stata golden input dump
#                  (data/interim/sim2_inputs_golden_2014.csv, from
#                  code/hpc/stage8_sim2dump.do) on (serial, pernum) and
#                  requires every input except sage to match exactly.
#          Part B: builds the R stacked/reflated frame with Stata's sage
#                  substituted and compares it row-by-row to the byte-exact
#                  golden TAXSIM input (data/interim/sim2_txpydata_golden.raw,
#                  from code/hpc/stage8_txpydump.do): id/demographic columns
#                  must be identical; money columns must agree within the
#                  %10.0g rounding tolerance.
#          Part C: feeds the golden bytes through taxsim35.exe and collapses
#                  with the R cell logic.
#          Part D: computes the sage-realization ambiguity set from the
#                  per-year files.
#          Gate:   every working-file cell must reproduce exactly OR lie in
#                  the ambiguity set; membership/weights must reproduce
#                  everywhere.
#          Part E: production run (correct sage, full precision) — reports
#                  the artifacts' combined cell-level impact; not a failure.
#
#          Requires data/interim/acs_2014_clean_r.rds (from 04_clean_acs.R)
#          and both stage-8 golden dumps.
#
# Usage:   Rscript code/validate/validate_sim2.R   (sbatch; ~48 GB)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
source(file.path("code", "lib", "qc_assignment.R"))
source(file.path("code", "lib", "clean_steps.R"))
source(file.path("code", "lib", "taxsim.R"))

suppressPackageStartupMessages(library(haven))

cpi_by_year <- lapply(params$prices$cpi99, float_round)

base2014 <- taxsim_inputs(readRDS(path_data("interim", "acs_2014_clean_r.rds"))) |>
  filter(primary_filer == 1)

# ---- Part A: input-level comparison against the Stata golden dump ----------

exact_vars <- c("state", "mstat", "depx", "page", "pwages", "swages",
                "psemp", "ssemp", "intrec", "otherprop",
                "education", "age_bracket", "female", "weight")

golden_in <- readr::read_csv(
  path_data("interim", "sim2_inputs_golden_2014.csv"),
  show_col_types = FALSE
)
stopifnot(nrow(golden_in) == nrow(base2014))

golden_j <- golden_in |>
  select(serial, pernum,
         dplyr::all_of(c(exact_vars, "sage", "tmp_first_dump",
                         "tmp_last_dump"))) |>
  rename_with(~ paste0(.x, "_g"), -c(serial, pernum))

cmp_in <- base2014 |>
  inner_join(golden_j, by = c("serial", "pernum"))
stopifnot(nrow(cmp_in) == nrow(base2014))

input_fails <- character(0)
for (v in exact_vars) {
  g <- cmp_in[[paste0(v, "_g")]]; r <- cmp_in[[v]]
  n_bad <- sum((is.na(g) != is.na(r)) |
                 (!is.na(g) & !is.na(r) & abs(g - r) > 1e-6 * pmax(abs(g), 1)))
  if (n_bad > 0) { message("INPUT MISMATCH ", v, ": ", n_bad, " rows")
                   input_fails <- c(input_fails, v) }
  else message("  OK input ", v)
}
if (length(input_fails) > 0)
  stop("sim2 input validation FAILED beyond sage: ",
       paste(input_fails, collapse = ", "))

n_sage_diff <- sum(cmp_in$sage != cmp_in$sage_g)
sage_diff <- cmp_in |> filter(sage != sage_g)
message("sage differs on ", n_sage_diff, " of ", nrow(cmp_in),
        " filers (", round(100 * n_sage_diff / nrow(cmp_in), 3), "%)")
# Contamination can only touch married multi-person units (the replace
# conditions require married == 1 & unit_ct > 1); anything else is a real bug.
stopifnot(all(sage_diff$married == 1 & sage_diff$unit_ct > 1))
message("  all sage differences are married, unit_ct > 1 rows ",
        "(consistent with cross-year hh_id collisions)")

# ---- Part B: stacked frame vs the byte-exact golden TAXSIM input ------------

base_compat <- base2014 |>
  select(-sage) |>
  inner_join(golden_in |> select(serial, pernum, sage),
             by = c("serial", "pernum"))
stopifnot(nrow(base_compat) == nrow(base2014))
stacked <- taxsim_sim2_stack(base_compat, cpi_by_year)

money_vars <- c("pwages", "swages", "psemp", "ssemp", "intrec", "otherprop")

txpy_path <- path_data("interim", "sim2_txpydata_golden.raw")
txpy_g <- read_csv(
  txpy_path, show_col_types = FALSE, guess_max = 1e6,
  col_types = do.call(cols, c(setNames(rep(list(col_character()),
                                           length(money_vars)), money_vars),
                              list(.default = col_double())))
)
names(txpy_g) <- ifelse(names(txpy_g) == "taxsimid", names(txpy_g),
                        paste0(names(txpy_g), "_g"))
stopifnot(nrow(txpy_g) == nrow(stacked))

cmp_st <- stacked |> inner_join(txpy_g, by = "taxsimid")
stopifnot(nrow(cmp_st) == nrow(stacked))

for (v in c("year", "state", "mstat", "page", "sage", "depx")) {
  n_bad <- sum(cmp_st[[v]] != cmp_st[[paste0(v, "_g")]])
  if (n_bad > 0) stop("stacked-frame mismatch on ", v, ": ", n_bad, " rows")
  message("  OK identical stacked ", v)
}

# Money columns: Stata's outsheet wrote the reflated doubles rounded (or
# truncated) to the %10.0g display format. The R value must agree with each
# printed golden string to within one unit of its last printed decimal place
# — anything beyond that is a real stacking/reflation bug (a wrong cpi float
# would shift values by ~6e-8 relative, orders of magnitude past this bound
# on typical rows).
ulp_of <- function(s) {
  has_e <- grepl("[eE]", s)
  expo  <- ifelse(has_e, suppressWarnings(as.numeric(sub(".*[eE]", "", s))), 0)
  mant  <- ifelse(has_e, sub("[eE].*", "", s), s)
  dec   <- ifelse(grepl("\\.", mant), nchar(sub(".*\\.", "", mant)), 0L)
  10^(expo - dec)
}
for (v in money_vars) {
  g_chr <- cmp_st[[paste0(v, "_g")]]
  d     <- abs(cmp_st[[v]] - as.numeric(g_chr))
  bound <- ulp_of(g_chr) * (1 + 1e-9) + 1e-12
  n_bad <- sum(d > bound)
  message("  stacked ", v, ": ", sum(d > 0), " rows differ from the golden ",
          "bytes (max abs ", signif(max(d), 3),
          ") — within outsheet %10.0g rounding")
  if (n_bad > 0)
    stop("stacked-frame money mismatch beyond %10.0g rounding on ", v,
         ": ", n_bad, " rows")
}
rm(cmp_st)

# ---- Part C: golden bytes -> taxsim35 -> R collapse -> working-file cells ---

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

cell_keys <- c("year", "state_soi", "female", "qc_ct", "mstat",
               "education", "age_bracket")

compare_cells <- function(cells_r, label) {
  cmp <- golden_cells |>
    left_join(cells_r, by = cell_keys)
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
  fails <- bad |> filter(is.na(sim2_fedeitc) | d_fed | d_st | d_wt)
  if (nrow(fails) > 0) print(fails |> head(8))
  list(n_unmatched = n_unmatched, n_bad = n_bad, fails = fails)
}

res_g <- run_taxsim35_file(txpy_path, col_select = c("taxsimid", "v25", "v39")) |>
  rename(sim2_fedeitc = v25, sim2_steitc = v39)
stopifnot(nrow(res_g) == nrow(stacked))

cells_golden <- stacked |>
  left_join(res_g, by = "taxsimid") |>
  taxsim_sim2_collapse()
res_golden <- compare_cells(cells_golden, "golden bytes")

# ---- Part D: sage-realization ambiguity set ---------------------------------
# The contaminated sage is NOT a fixed value: `sort hh_id unit_id pernum` on
# the combined file is an unstable sort over keys that collide across years,
# and tmp_min/max_age are the FIRST/LAST rows' ages within (hh_id, unit_id)
# — so where the extremal-pernum rows carry more than one age, the realized
# sage depends on Stata's arbitrary tie order and differs across runs (the
# original 01_clean_data.do run drew a different realization than the golden
# dumps, whose two runs agree with each other). Those cells are
# irreproducible in principle; the validation gate is therefore:
#   (i)  every cell OUTSIDE the ambiguity set reproduces exactly from the
#        byte-exact golden inputs, and
#   (ii) every failing cell contains >= 1 filer whose sage is
#        realization-ambiguous (and is married, the only rows sage touches).

comb <- bind_rows(lapply(2006:2019, function(y) {
  read_dta(path_data("final", sprintf("acs_%d_clean.dta", y)),
           col_select = c(hh_id, unit_id, pernum, age)) |> zap_labels()
}))
ext <- comb |>
  group_by(hh_id, unit_id) |>
  summarise(pmin = min(pernum), pmax = max(pernum), .groups = "drop")
comb_e <- comb |> inner_join(ext, by = c("hh_id", "unit_id"))
A1 <- comb_e |> filter(pernum == pmin) |> distinct(hh_id, unit_id, t1 = age)
A2 <- comb_e |> filter(pernum == pmax) |> distinct(hh_id, unit_id, t2 = age)
rm(comb, comb_e, ext)

# All possible sage realizations per married multi-person 2014 filer:
# replicate the two `replace` statements — the SECOND overwrites the first,
# so sage(t1, t2) = t1 if page == t2, else t2 if page == t1, else 0.
cand <- golden_in |>
  filter(married == 1, unit_ct > 1) |>
  select(serial, pernum, hh_id, unit_id, page, sage_g = sage)
pairs <- cand |>
  inner_join(A1, by = c("hh_id", "unit_id"),
             relationship = "many-to-many") |>
  inner_join(A2, by = c("hh_id", "unit_id"),
             relationship = "many-to-many") |>
  mutate(s = ifelse(page == t2, t1, ifelse(page == t1, t2, 0)))
sage_sets <- pairs |>
  group_by(serial, pernum) |>
  summarise(n_sage = n_distinct(s), golden_in_set = any(s == first(sage_g)),
            .groups = "drop")
rm(pairs, A1, A2)
# The golden dump's sage must be one attainable realization for every filer
# — otherwise our model of the Stata computation is wrong.
stopifnot(all(sage_sets$golden_in_set))
amb_filers <- sage_sets |> filter(n_sage > 1)
message("sage-ambiguous filers: ", nrow(amb_filers), " of ", nrow(cand),
        " married multi-person 2014 filers")

amb_keys <- base_compat |>
  semi_join(amb_filers, by = c("serial", "pernum")) |>
  distinct(state_soi = state, female, qc_ct = depx, mstat,
           education, age_bracket)
amb_cells <- bind_rows(lapply(2010:2019, function(y)
  amb_keys |> mutate(year = y)))
message("cells containing >= 1 sage-ambiguous filer: ", nrow(amb_cells),
        " of ", nrow(golden_cells), " (",
        round(100 * nrow(amb_cells) / nrow(golden_cells), 1), "%)")

fails_outside <- res_golden$fails |> anti_join(amb_cells, by = cell_keys)

# ---- Part E: production run (correct sage, full precision) ------------------
# Differences here are the documented impact of the Stata artifacts, not a
# validation failure.

cells_correct <- taxsim_sim2_cells(base2014, cpi_by_year)
res_correct <- compare_cells(cells_correct, "production (impact report)")

# ---- Gate --------------------------------------------------------------------

if (res_golden$n_unmatched > 0 || res_golden$n_bad["d_wt"] > 0)
  stop("sim2 validation FAILED: cell membership/weights do not reproduce")
if (nrow(fails_outside) > 0) {
  print(fails_outside |> head(8))
  stop("sim2 validation FAILED: ", nrow(fails_outside), " diverging cells ",
       "lie OUTSIDE the sage-ambiguity set — a divergence exists beyond ",
       "the documented artifacts")
}

message("===== sim2 validation PASSED =====")
message("Byte-exact golden inputs reproduce ",
        nrow(golden_cells) - nrow(res_golden$fails), " of ",
        nrow(golden_cells), " working-file cells through the R collapse; ",
        "all ", nrow(res_golden$fails), " diverging cells sit inside the ",
        "sage-realization ambiguity set (unstable-sort tie order in the ",
        "original run, irreproducible in principle). The stacked frame ",
        "matches the golden input row-for-row (money within outsheet ",
        "%10.0g rounding). The full-precision correct-sage production run ",
        "differs on ", nrow(res_correct$fails), " cells (documented ",
        "artifact impact).")
