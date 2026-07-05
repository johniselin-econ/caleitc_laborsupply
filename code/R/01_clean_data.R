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
source(file.path("code", "R", "utils", "taxsim.R"))

args_years <- as.integer(commandArgs(trailingOnly = TRUE))
years <- if (length(args_years) > 0) args_years else
  seq(params$years$data_start, params$years$data_end)

aux <- load_aux_data()
cpi99_2019 <- params$prices$cpi99[["2019"]]
caleitc_params <- load_caleitc_params()
# Stata's ${cpi_2015} is the mean of the float-stored cpi99 in acs_2015.csv
cpi_2015 <- float_round(params$prices$cpi99[["2015"]])

for (y in years) {
  df <- clean_acs_year(y, aux, cpi99_2019 = cpi99_2019) |>
    rename(weight = perwt)

  # Step 9: TAXSIM sims 1 and 3 (2010-2019 only), same local binary as Stata
  if (y >= 2010 && y <= 2019) {
    df <- taxsim_inputs(df) |>
      taxsim_sim1() |>
      taxsim_sim3(caleitc_params, cpi_2015) |>
      # temp TAXSIM inputs dropped as in Stata (state_soi + mstat kept for sim2)
      select(-depx, -page, -sage, -pwages, -swages, -psemp, -ssemp,
             -intrec, -otherprop, -primary_filer, -taxsimid, -state)
  }

  out <- path_data("interim", paste0("acs_", y, "_clean_r.rds"))
  saveRDS(df, out)
  message("Saved ", out, " (N = ", nrow(df), ")")
  rm(df); invisible(gc())
}

# Simulation 2 (cell instrument on the combined file) runs after all years —
# see taxsim_sim2_cells(); wiring into the combined-file assembly comes with
# the working-file port.

message("01_clean_data.R complete.")
