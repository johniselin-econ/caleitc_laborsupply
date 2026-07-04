# =============================================================================
# File:    validate_clean_year.R
# Purpose: Row-for-row validation of the Steps 1-8 cleaning port against the
#          Stata per-year files data/final/acs_<y>_clean.dta (produced by the
#          2026-07-02 stage-1 rebuild on the canonical extract).
#
#          Joins on (serial, pernum) and compares every ported column that
#          exists in the Stata file: integer/indicator columns exactly,
#          real-typed columns to float precision (the Stata files are
#          `compress`ed, so doubles are stored as float ~7 significant
#          digits). TAXSIM columns are not ported yet and not compared.
#
# Usage:   Rscript code/R/validate/validate_clean_year.R   (sbatch; ~30 GB)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))
source(file.path("code", "R", "utils", "qc_assignment.R"))
source(file.path("code", "R", "utils", "clean_steps.R"))

suppressPackageStartupMessages(library(haven))

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
  "state_fips", "county_fips", "state_status", "weight"
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
  "state_unemp", "mean_st_mw", "county_unemp"
)

validate_year <- function(y, aux, cpi99_2019) {

  message("===== Validating cleaning port for ", y, " =====")

  ported <- clean_acs_year(y, aux, cpi99_2019 = cpi99_2019) |>
    rename(weight = perwt)

  stata_file <- path_data("final", paste0("acs_", y, "_clean.dta"))
  golden <- read_dta(stata_file,
                     col_select = dplyr::any_of(c("serial", "pernum",
                                                  INT_COLS, REAL_COLS))) |>
    zap_labels()

  int_cols  <- intersect(INT_COLS,  names(golden))
  real_cols <- intersect(REAL_COLS, names(golden))
  message("Comparing ", length(int_cols), " integer + ", length(real_cols),
          " real columns; skipped (absent in dta): ",
          paste(setdiff(c(INT_COLS, REAL_COLS), names(golden)), collapse = " "))

  stopifnot(nrow(ported) == nrow(golden))

  cmp <- golden |>
    inner_join(ported, by = c("serial", "pernum"),
               suffix = c("_g", "_r"))
  stopifnot(nrow(cmp) == nrow(golden))

  fails <- character(0)

  for (v in int_cols) {
    g <- cmp[[paste0(v, "_g")]]; r <- cmp[[paste0(v, "_r")]]
    n_bad <- sum(dplyr::coalesce(g, -999999) != dplyr::coalesce(r, -999999))
    if (n_bad > 0) {
      fails <- c(fails, v)
      message("  MISMATCH ", v, ": ", n_bad, " rows")
    }
  }

  for (v in real_cols) {
    g <- cmp[[paste0(v, "_g")]]; r <- cmp[[paste0(v, "_r")]]
    tol <- pmax(abs(dplyr::coalesce(g, 0)) * 1e-6, 1e-4)
    bad <- abs(dplyr::coalesce(g, 0) - dplyr::coalesce(r, 0)) > tol |
      (is.na(g) != is.na(r))
    if (sum(bad) > 0) {
      fails <- c(fails, v)
      message("  MISMATCH ", v, ": ", sum(bad), " rows; e.g.")
      print(head(cmp[bad, c("serial", "pernum",
                            paste0(v, "_g"), paste0(v, "_r"))], 5))
    }
  }

  if (length(fails) > 0) stop("Cleaning validation FAILED for ", y, ": ",
                              paste(fails, collapse = ", "))

  message("PASS: ", y, " — ", nrow(cmp), " rows, ",
          length(int_cols) + length(real_cols), " columns identical")
  invisible(TRUE)
}

aux <- load_aux_data()
cpi99_2019 <- params$prices$cpi99[["2019"]]

for (y in c(2012, 2015)) {
  validate_year(y, aux, cpi99_2019)
  invisible(gc())
}

message("===== cleaning-port validation PASSED for all years =====")
