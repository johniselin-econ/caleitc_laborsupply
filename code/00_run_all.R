# =============================================================================
# File:    00_run_all.R
# Purpose: Master driver for the R pipeline (Stata-to-R migration, Phase 1+).
#          Mirrors code/00_caleitc.do. Run from the repo root:
#              Rscript code/00_run_all.R
#          or source() interactively. renv activates via the root .Rprofile.
#
#          Phase 1 scope: configuration + data download (the two scripts
#          formerly invoked from Stata via rcall now run natively).
#          Later phases add cleaning, estimation, inference, SDID, MVPF.
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))

set.seed(params$seed)

## Run switches (mirror the 00_caleitc.do globals)
run_download_acs   <- FALSE   # IPUMS extract, ~hours; data/acs/ already populated
run_download_other <- FALSE   # FIPS, BLS unemployment, minimum wage
overwrite_csv      <- FALSE
overwrite_bls      <- FALSE

# =============================================================================
# (01) Data download
# =============================================================================

if (run_download_acs) {
  project_root   <- here::here()
  dir_data_acs   <- path_data("acs")
  api_codes_path <- cfg$api_codes
  start_year     <- params$years$data_start
  end_year       <- params$years$data_end
  source(file.path("code", "01_download_acs.R"))
}

if (run_download_other) {
  dir_data_raw    <- path_data("raw")
  dir_data_int    <- path_data("interim")
  start_year_data <- params$years$data_start
  end_year_data   <- params$years$data_end
  source(file.path("code", "02_download_aux.R"))
}

# =============================================================================
# (02+) Cleaning / estimation — added in later migration phases
# =============================================================================

message("00_run_all.R complete.")
