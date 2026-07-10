# =============================================================================
# File:    validate_working_file.R
# Purpose: Row-for-row validation of the assembled working file
#          (data/final/acs_working_file_r.rds, from code/05_working_file.R)
#          against Stata's data/final/acs_working_file.dta.
#
#          Joins on (year, serial, pernum) and compares every listed column:
#          integer/indicator columns exactly, real-typed columns to float
#          precision (the Stata file is `compress`ed). Columns present in the
#          dta but not listed are reported, not compared.
#
#          Sim-2 columns get the documented carve-out (see the DELIBERATE
#          NON-PORTS note in code/lib/taxsim.R and validate_sim2.R): the
#          R port uses the correct 2014-only sage at full input precision,
#          while the Stata values embed a contaminated, run-specific sage
#          realization. Row-level sim-2 value mismatches are therefore
#          allowed ONLY on married rows (the only rows sage touches), and are
#          reported as cell counts; taxsim_sim2_wt (cell membership) and the
#          NA pattern must reproduce exactly everywhere. The rigorous
#          cell-level sim-2 gate is validate_sim2.R.
#
# Usage:   Rscript code/validate/validate_working_file.R   (sbatch; ~60 GB)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
})

INT_COLS <- c(
  "hh_id", "child", "adult", "elder", "unit_id", "unit_ct",
  "age_test", "citizen_test", "joint_test", "qc",
  "hoh", "sibling", "foster", "grandchild",
  "qc_ct", "matched", "min_qc_age",
  "kid_ct", "qc_present", "kid_present", "parent_ct",
  "minage_qc_compr", "minage_qc", "minage_kid",
  "hh_person_ct", "hh_child_ct", "hh_qc_ct", "hh_adult_ct",
  "hh_child_present", "hh_qc_present",
  "age", "age_sample_20_50", "age_sample_20_49", "age_sample_25_54",
  "education", "in_school", "age_bracket", "age_grps",
  "married", "mfs", "hispanic", "race_group", "race_hisp", "female",
  "employed_y", "employed_y_reported", "employed_w", "employed_w_reported",
  "labor_force_w", "hours_worked_y_reported", "weeks_worked_y_reported",
  "part_time_y", "full_time_y", "part_time_y_31", "full_time_y_31",
  "part_time_y_39", "full_time_y_39",
  "self_employed_w", "self_employed_y", "self_employed_pos_y",
  "armed_services",
  "incearn_reported", "incwage_reported", "incse_reported",
  "incinvst_reported",
  "state_fips", "county_fips", "state_status", "weight",
  "state_soi", "mstat"
)

REAL_COLS <- c(
  "hours_worked_y", "weeks_worked_y", "se_income_y",
  "inctot_real", "inctot_nom", "incearn_real", "incearn_nom",
  "incwage_real", "incwage_nom", "incse_real", "incse_nom",
  "incinvst_real", "incinvst_nom", "incwel_real", "incwel_nom",
  "inctot_hh_real", "inctot_hh_nom", "inctot_tax_real", "inctot_tax_nom",
  "incearn_hh_real", "incearn_hh_nom", "incearn_tax_real", "incearn_tax_nom",
  "incwage_hh_real", "incwage_hh_nom", "incwage_tax_real", "incwage_tax_nom",
  "incse_hh_real", "incse_hh_nom", "incse_tax_real", "incse_tax_nom",
  "incinvst_hh_real", "incinvst_hh_nom", "incinvst_tax_real", "incinvst_tax_nom",
  "state_unemp", "mean_st_mw", "county_unemp", "cpi99",
  "taxsim_sim1_fedeitc", "taxsim_sim1_steitc", "taxsim_sim3_atr_st"
)

SIM2_VAL_COLS <- c("taxsim_sim2_fedeitc", "taxsim_sim2_steitc")

wf_dta <- path_data("final", "acs_working_file.dta")

ported <- readRDS(path_data("final", "acs_working_file_r.rds"))
message("ported working file: ", nrow(ported), " rows, ",
        ncol(ported), " columns")

# ---- Row alignment on (year, serial, pernum) --------------------------------

gk <- read_dta(wf_dta, col_select = c(year, serial, pernum)) |> zap_labels()
stopifnot(nrow(gk) == nrow(ported))

map <- gk |>
  mutate(gi = row_number()) |>
  inner_join(ported |>
               transmute(year, serial, pernum, ri = row_number()),
             by = c("year", "serial", "pernum"))
stopifnot(nrow(map) == nrow(gk))
gi <- map$gi; ri <- map$ri
rm(gk, map); invisible(gc())
message("row alignment OK (unique (year, serial, pernum) match)")

# ---- Column comparison, batched dta reads -----------------------------------

dta_cols <- names(read_dta(wf_dta, n_max = 0))
int_cols  <- intersect(INT_COLS,  intersect(dta_cols, names(ported)))
real_cols <- intersect(REAL_COLS, intersect(dta_cols, names(ported)))
uncompared <- setdiff(dta_cols, c("year", "serial", "pernum", int_cols,
                                  real_cols, SIM2_VAL_COLS, "taxsim_sim2_wt"))
if (length(uncompared) > 0)
  message("NOT COMPARED (present in dta, unlisted): ",
          paste(uncompared, collapse = " "))
missing_in_r <- setdiff(intersect(c(INT_COLS, REAL_COLS), dta_cols),
                        names(ported))
if (length(missing_in_r) > 0)
  message("MISSING in ported file: ", paste(missing_in_r, collapse = " "))

fails <- character(0)

compare_batch <- function(cols) {
  g <- read_dta(wf_dta, col_select = dplyr::all_of(cols)) |> zap_labels()
  for (v in cols) {
    gv <- g[[v]][gi]; rv <- ported[[v]][ri]
    if (v %in% int_cols) {
      n_bad <- sum(coalesce(gv, -999999) != coalesce(rv, -999999))
    } else {
      tol <- pmax(abs(coalesce(gv, 0)) * 1e-6, 1e-4)
      n_bad <- sum(abs(coalesce(gv, 0) - coalesce(rv, 0)) > tol |
                     (is.na(gv) != is.na(rv)))
    }
    if (n_bad > 0) {
      fails <<- c(fails, v)
      message("  MISMATCH ", v, ": ", n_bad, " rows")
    } else message("  OK ", v)
  }
  rm(g); invisible(gc())
}

all_cmp <- c(int_cols, real_cols)
for (batch in split(all_cmp, ceiling(seq_along(all_cmp) / 10)))
  compare_batch(batch)

if (length(fails) > 0)
  stop("working-file validation FAILED: ", paste(fails, collapse = ", "))

# ---- Sim-2 columns: carve-out for the sage-realization artifact -------------

g2 <- read_dta(wf_dta, col_select = dplyr::all_of(c(SIM2_VAL_COLS,
                                                    "taxsim_sim2_wt"))) |>
  zap_labels()

wt_g <- g2$taxsim_sim2_wt[gi]; wt_r <- ported$taxsim_sim2_wt[ri]
n_bad_wt <- sum(coalesce(wt_g, -1) != coalesce(wt_r, -1))
if (n_bad_wt > 0)
  stop("taxsim_sim2_wt mismatch on ", n_bad_wt,
       " rows — cell membership must reproduce exactly")
message("  OK taxsim_sim2_wt (exact, incl. NA pattern)")

mm_rows <- rep(FALSE, length(gi))
for (v in SIM2_VAL_COLS) {
  gv <- g2[[v]][gi]; rv <- ported[[v]][ri]
  if (any(is.na(gv) != is.na(rv)))
    stop(v, ": NA pattern differs on ", sum(is.na(gv) != is.na(rv)), " rows")
  bad <- !is.na(gv) &
    abs(coalesce(gv, 0) - coalesce(rv, 0)) >
      pmax(abs(coalesce(gv, 0)) * 1e-5, 2e-2)
  message("  ", v, ": ", sum(bad), " rows differ (sage artifact carve-out)")
  mm_rows <- mm_rows | bad
}
if (any(mm_rows)) {
  not_married <- sum(ported$married[ri][mm_rows] != 1)
  if (not_married > 0)
    stop("sim-2 divergence on ", not_married, " NON-married rows — outside ",
         "the documented sage artifact")
  idx <- ri[mm_rows]
  n_cells <- ported[idx, c("year", "state_soi", "female", "qc_ct", "mstat",
                           "education", "age_bracket")] |>
    distinct() |>
    nrow()
  message("  sim-2 divergence confined to married rows in ", n_cells,
          " cells (correct-sage production vs the run-specific Stata ",
          "realization; rigorously gated in validate_sim2.R)")
}

message("===== working-file validation PASSED =====")
message(length(all_cmp), " columns identical on ", length(gi),
        " rows; sim-2 values carve-out as documented.")
