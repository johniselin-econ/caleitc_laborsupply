# =============================================================================
# File:    01_clean_data.R
# Purpose: R port of the 01_clean_data.do per-year cleaning pipeline,
#          Steps 1-8 (prep, qc_assignment, household composition,
#          demographics, employment, earnings, aux merges, treatment
#          assignment). TAXSIM (Step 9 / sims 1-3) is NOT yet ported — see
#          PLAN.md Phase 2 status.
#
#          Writes data/interim/acs_<year>_clean_r.rds per year (gitignored).
#          Validated row-for-row against the Stata per-year files for
#          2012 + 2015 by code/R/validate/validate_clean_year.R.
#
# Usage:   Rscript code/R/01_clean_data.R [year ...]   (default: 2006-2019)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))
source(file.path("code", "R", "utils", "qc_assignment.R"))
source(file.path("code", "R", "utils", "clean_steps.R"))

args_years <- as.integer(commandArgs(trailingOnly = TRUE))
years <- if (length(args_years) > 0) args_years else
  seq(params$years$data_start, params$years$data_end)

aux <- load_aux_data()
cpi99_2019 <- params$prices$cpi99[["2019"]]

for (y in years) {
  df <- clean_acs_year(y, aux, cpi99_2019 = cpi99_2019) |>
    rename(weight = perwt)
  out <- path_data("interim", paste0("acs_", y, "_clean_r.rds"))
  saveRDS(df, out)
  message("Saved ", out, " (N = ", nrow(df), ")")
  rm(df); invisible(gc())
}

message("01_clean_data.R complete.")
