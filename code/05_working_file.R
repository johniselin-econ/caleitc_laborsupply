# =============================================================================
# File:    05_working_file.R
# Purpose: R port of 01_clean_data.do sections (4)-(5): append the per-year
#          cleaned files, run TAXSIM Simulation 2 (cell-based simulated
#          instrument from 2014 primary filers), merge the cell values back,
#          and save the combined working file.
#
#          Requires the per-year RDS files from code/04_clean_acs.R.
#          Note: sim 2 needs the TAXSIM input variables, which the per-year
#          outputs drop (as Stata does) — they are rebuilt here for 2014 via
#          taxsim_inputs(), which is deterministic given the cleaned frame.
#
# Usage:   Rscript code/05_working_file.R   (sbatch; ~96 GB for all years)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
source(file.path("code", "lib", "qc_assignment.R"))
source(file.path("code", "lib", "clean_steps.R"))
source(file.path("code", "lib", "taxsim.R"))

years <- seq(params$years$data_start, params$years$data_end)

# ---- (4) Append all years -----------------------------------------------

combined <- bind_rows(lapply(years, function(y) {
  f <- path_data("interim", paste0("acs_", y, "_clean_r.rds"))
  if (!file.exists(f)) { message("skipping missing ", f); return(NULL) }
  readRDS(f)
}))
message("Combined file: ", nrow(combined), " rows")

# ---- (5) Simulation 2 -----------------------------------------------------

# Stata's `local cpi_y = mean cpi99 if year == y` over float-stored values
cpi_by_year <- lapply(params$prices$cpi99, float_round)

# Rebuild TAXSIM inputs for the 2014 filers (dropped from per-year outputs)
base2014 <- taxsim_inputs(readRDS(path_data("interim", "acs_2014_clean_r.rds")))

cells <- taxsim_sim2_cells(base2014, cpi_by_year)

combined <- combined |>
  left_join(cells, by = c("year", "state_soi", "female",
                          "qc_ct", "mstat", "education", "age_bracket")) |>
  mutate(taxsim_sim2_fedeitc = sim2_fedeitc,
         taxsim_sim2_steitc  = sim2_steitc,
         taxsim_sim2_wt      = sim2_cellwt) |>
  select(-sim2_fedeitc, -sim2_steitc, -sim2_cellwt)

saveRDS(combined, path_data("final", "acs_working_file_r.rds"))
message("Saved acs_working_file_r.rds (N = ", nrow(combined), ")")
