# =============================================================================
# Author: John Iselin
# Date:   January 2026
# File:   01_data_prep_other.R
#
# Purpose: Download and prepare non-IPUMS data:
#          - State and county FIPS codes
#          - BLS unemployment data (state and county level)
#          - State minimum wage data (Vaghul & Zipperer 2022)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(tidycensus)
  library(blsR)
  library(readxl)
})

# =============================================================================
# Configuration
# =============================================================================

# Set paths (can be overwritten when sourced from main script)
if (!exists("dir_data_raw")) dir_data_raw <- here::here("data", "raw")
if (!exists("dir_data_int")) dir_data_int <- here::here("data", "interim")
if (!exists("start_year_data")) start_year_data <- 2006
if (!exists("end_year_data")) end_year_data <- 2019
if (!exists("overwrite_bls")) overwrite_bls <- 0

# Create directories if needed
dir.create(dir_data_raw, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_data_int, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# (1) State and County FIPS Codes from tidycensus
# =============================================================================

message("Preparing state and county FIPS codes...")

# Get state and county info from tidycensus
county_info <- tidycensus::fips_codes %>%
  rename(
    state_fips  = state_code,
    state_abb   = state,
    county_fips = county_code,
    county_name = county
  ) %>%
  mutate(fips = paste0(state_fips, county_fips))

# State info (unique states)
state_info <- county_info %>%
  select(state_fips, state_name, state_abb) %>%
  distinct() %>%
  filter(as.numeric(state_fips) <= 56)

# Save state info for Stata
write.csv(state_info, file.path(dir_data_int, "state_info.csv"), row.names = FALSE)

# =============================================================================
# (2) BLS State-Level Unemployment Data via API
# =============================================================================

message("Preparing BLS state unemployment data...")

rds_file_annual  <- file.path(dir_data_int, "bls_state_unemployment_annual.rds")
rds_file_monthly <- file.path(dir_data_int, "bls_state_unemployment_monthly.rds")

if (!file.exists(rds_file_monthly) || overwrite_bls == 1) {

  # Get state fips codes
  state_fips_vec <- state_info %>%
    pull(state_fips) %>%
    as.vector()

  # Create series IDs for seasonally adjusted unemployment rates
  # Format: LASST{state_fips}0000000000003
  series_ids <- paste0("LASST", state_fips_vec, "0000000000003")

  # Download data via BLS API
  data_all_states <- blsR::get_n_series_table(
    series_ids = series_ids,
    start_year = start_year_data,
    end_year   = end_year_data
  )

  # Clean data: reshape to long format
  state_unemp_monthly <- data_all_states %>%
    pivot_longer(
      cols      = starts_with("LASST"),
      names_to  = "variable",
      values_to = "value"
    ) %>%
    # Extract state FIPS from variable name
    mutate(
      state_fips = str_extract(variable, "\\d{2}(?=0000000000003$)")
    ) %>%
    select(year, period, state_fips, value) %>%
    left_join(state_info, by = "state_fips") %>%
    rename(month = period)

  # Create annual version (average across months)
  state_unemp_annual <- state_unemp_monthly %>%
    group_by(year, state_name, state_abb, state_fips) %>%
    summarise(
      value = mean(value, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    ungroup()

  # Save files
  saveRDS(state_unemp_monthly, rds_file_monthly)
  saveRDS(state_unemp_annual, rds_file_annual)

  # Also save CSV for Stata
  write.csv(state_unemp_annual, file.path(dir_data_int, "bls_state_unemployment_annual.csv"),
            row.names = FALSE)
  
  write.csv(state_unemp_monthly, file.path(dir_data_int, "bls_state_unemployment_monthly.csv"),
            row.names = FALSE)
  
  rm(state_unemp_monthly, state_unemp_annual, data_all_states, series_ids)
  message("  State unemployment data downloaded and saved.")

} else {
  message("  State unemployment data already exists, skipping download.")
}

# =============================================================================
# (3) BLS County-Level Unemployment Data
# =============================================================================

message("Preparing BLS county unemployment data...")

# Note: County-level data must be downloaded manually from BLS LAUS
# Link: https://download.bls.gov/pub/time.series/la/
# Download la.data.64.County file to data/raw/

unemp_county_path <- file.path(dir_data_raw, "la.data.64.County")

rds_file_annual  <- file.path(dir_data_int, "bls_county_unemployment_annual.rds")
rds_file_monthly <- file.path(dir_data_int, "bls_county_unemployment_monthly.rds")

if (file.exists(unemp_county_path)) {

  # Import data
  county_unemp_monthly <- read.delim(
    unemp_county_path,
    header = TRUE,
    sep    = "\t",
    quote  = ""
  ) %>%
    # Keep required variables
    select(series_id, year, period, value) %>%
    # Clean up series id, extracting data type and fips code
    mutate(
      fips  = substr(series_id, 6, 10),
      type  = substr(series_id, 20, 20),
      value = as.numeric(trimws(value))
    ) %>%
    # Keep only unemployment rate (type 3)
    filter(
      type == "3",
      year >= start_year_data & year <= end_year_data
    ) %>%
    select(fips, year, month = period, value) %>%
    # Merge with county info
    left_join(county_info, by = "fips")

  # Create annual version
  county_unemp_annual <- county_unemp_monthly %>%
    group_by(fips, year, state_abb, state_fips, state_name, county_fips, county_name) %>%
    summarise(
      value = mean(value, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    ungroup()

  # Save files
  saveRDS(county_unemp_monthly, rds_file_monthly)
  saveRDS(county_unemp_annual, rds_file_annual)

  # Also save CSV for Stata
  write.csv(county_unemp_annual, file.path(dir_data_int, "bls_county_unemployment_annual.csv"),
            row.names = FALSE)

  rm(county_unemp_annual, county_unemp_monthly)
  message("  County unemployment data processed and saved.")

} else {
  message("  WARNING: County unemployment file not found at: ", unemp_county_path)
  message("  Please download from: https://download.bls.gov/pub/time.series/la/")
}

# =============================================================================
# (4) State Minimum Wage Data (Vaghul & Zipperer 2022)
# =============================================================================

message("Preparing state minimum wage data...")

rds_file_annual <- file.path(dir_data_int, "VKZ_state_minwage_annual.rds")
rds_file_subannual <- file.path(dir_data_int, "VKZ_substate_minwage_annual.rds")

# Define URLs for minimum wage data
url_state    <- "https://github.com/benzipperer/historicalminwage/releases/download/v1.4.0/mw_state_excel.zip"
url_substate <- "https://github.com/benzipperer/historicalminwage/releases/download/v1.4.0/mw_substate_excel.zip"

# Define destination paths
dest_state    <- file.path(dir_data_raw, "mw_state_excel.zip")
dest_substate <- file.path(dir_data_raw, "mw_substate_excel.zip")

# Download files if not present
if (!file.exists(dest_state)) {
  download.file(url_state, dest_state, mode = "wb")
}
if (!file.exists(dest_substate)) {
  download.file(url_substate, dest_substate, mode = "wb")
}

# Unzip into data directory
outdir <- file.path(dir_data_int, "minwage_data")
dir.create(outdir, showWarnings = FALSE)

unzip(dest_state, exdir = outdir, overwrite = TRUE)
unzip(dest_substate, exdir = outdir, overwrite = TRUE)

# Get state-level minimum wage information
state_minwage <- read_excel(file.path(outdir, "mw_state_annual.xlsx")) %>%
  select(
    state_fips    = `State FIPS Code`,
    year          = Year,
    state_minwage = `Annual State Average`
  ) %>%
  mutate(
    state_fips = if_else(
      str_length(as.character(state_fips)) == 2,
      as.character(state_fips),
      paste0("0", as.character(state_fips))
    )
  ) %>%
  left_join(state_info, by = "state_fips") %>%
  select(year, state_fips, state_name, state_abb, state_minwage)

# Save as RDS file
saveRDS(state_minwage, rds_file_annual)

# Also save CSV for Stata
write.csv(state_minwage, file.path(dir_data_int, "VKZ_state_minwage_annual.csv"),
          row.names = FALSE)

rm(state_minwage)
message("  State minimum wage data processed and saved.")


# Get substate-level minimum wage information
substate_minwage <- read_excel(file.path(outdir, "mw_substate_annual.xlsx")) %>%
  select(
    state_fips    = `State FIPS Code`,
    substate_name = `City/County`,
    year          = Year,
    substate_minwage = `Annual Average`, 
    substate_gr_state = `Local > State min wage`
  ) %>%
  mutate(
    state_fips = if_else(
      str_length(as.character(state_fips)) == 2,
      as.character(state_fips),
      paste0("0", as.character(state_fips))
    )
  ) %>%
  left_join(state_info, by = "state_fips") %>%
  select(year, state_fips, state_name, state_abb, substate_name, substate_minwage, substate_gr_state)

# Save as RDS file
saveRDS(substate_minwage, rds_file_subannual)

# Also save CSV for Stata
write.csv(substate_minwage, file.path(dir_data_int, "VKZ_substate_minwage_annual.csv"),
          row.names = FALSE)

rm(substate_minwage)
message("  Sub-State minimum wage data processed and saved.")

# =============================================================================
# Clean up
# =============================================================================

rm(county_info, state_info)
gc()

message("Non-IPUMS data preparation complete.")
