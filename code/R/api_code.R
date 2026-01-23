# =============================================================================
# Author: John Iselin
# Date:   January 2026
# File:   api_code.R
#
# Purpose: Download ACS microdata via IPUMS (year-by-year) and write per-year
#          CSV files for import into Stata. This script is called from Stata
#          via rcall.
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ipumsr)
  library(stringr)
})

# ---- Helper: read IPUMS key from api_codes.txt ----
.read_ipums_key <- function(api_codes_path) {
  if (!file.exists(api_codes_path)) {
    stop("STOP, NO API KEYS: file not found at: ", api_codes_path, call. = FALSE)
  }

  api_codes <- tryCatch(
    read.delim(api_codes_path, sep = ",", header = TRUE, stringsAsFactors = FALSE),
    error = function(e) read.delim(api_codes_path, sep = ",", header = FALSE, stringsAsFactors = FALSE)
  )

  # Find row with "ipums" in column 1
  ipums_key <- NA_character_
  if (ncol(api_codes) >= 2) {
    col1 <- tolower(trimws(as.character(api_codes[[1]])))
    idx  <- which(grepl("ipums", col1))
    if (length(idx) >= 1) ipums_key <- as.character(api_codes[idx[1], 2])
  }

  # Fallback: first row, second column
  if (is.na(ipums_key) && ncol(api_codes) >= 2 && nrow(api_codes) >= 1) {
    ipums_key <- as.character(api_codes[1, 2])
  }

  ipums_key <- stringr::str_trim(ipums_key)

  if (is.na(ipums_key) || ipums_key == "") {
    stop("Could not parse an IPUMS key from: ", api_codes_path, call. = FALSE)
  }

  ipums_key
}

# ---- Main function: Download IPUMS ACS Data ----
download_ipums_acs <- function(project_root,
                               dir_data_acs,
                               api_codes_path,
                               start_year = 2006,
                               end_year   = 2019,
                               overwrite_csv = FALSE,
                               overwrite_extract_files = TRUE,
                               extract_desc_prefix = "ACS microdata for CalEITC") {

  # Normalize paths (Windows-safe)
  project_root   <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  dir_data_acs   <- normalizePath(dir_data_acs, winslash = "/", mustWork = FALSE)
  api_codes_path <- normalizePath(api_codes_path, winslash = "/", mustWork = TRUE)

  if (!dir.exists(dir_data_acs)) {
    dir.create(dir_data_acs, recursive = TRUE, showWarnings = FALSE)
  }

  setwd(project_root)

  # IPUMS key setup
  ipums_key <- .read_ipums_key(api_codes_path)
  ipumsr::set_ipums_api_key(ipums_key, save = TRUE, overwrite = TRUE)

  # Years
  years <- seq.int(start_year, end_year)
  if (length(years) == 0) stop("start_year must be <= end_year", call. = FALSE)

  for (y in years) {

    file_acs <- file.path(dir_data_acs, paste0("acs_", y, ".csv"))

    if (!file.exists(file_acs) || isTRUE(overwrite_csv)) {

      message("Downloading ACS data for ", y, " via IPUMS...")

      extract_name <- paste0(extract_desc_prefix, ", Year: ", y)

      # Variable specifications for CalEITC analysis
      # Following 01_data_prep_ipums.R from caleitc project

      gq       <- var_spec("GQ", case_selections = c("1", "2"))
      workedyr <- var_spec("WORKEDYR", data_quality_flags = TRUE)
      empstat  <- var_spec("EMPSTAT", data_quality_flags = TRUE)
      empstatd <- var_spec("EMPSTATD", data_quality_flags = TRUE)
      classwkr <- var_spec("CLASSWKR", data_quality_flags = TRUE)
      wkswork2 <- var_spec("WKSWORK2", data_quality_flags = TRUE)
      uhrswork <- var_spec("UHRSWORK", data_quality_flags = TRUE)
      labforce <- var_spec("LABFORCE", data_quality_flags = TRUE)
      inctot   <- var_spec("INCTOT", data_quality_flags = TRUE)
      incwage  <- var_spec("INCWAGE", data_quality_flags = TRUE)
      incbus00 <- var_spec("INCBUS00", data_quality_flags = TRUE)
      incearn  <- var_spec("INCEARN", data_quality_flags = TRUE)
      incinvst <- var_spec("INCINVST", data_quality_flags = TRUE)
      incwelfr <- var_spec("INCWELFR", data_quality_flags = TRUE)
      incsupp  <- var_spec("INCSUPP", data_quality_flags = TRUE)
      incother <- var_spec("INCOTHER", data_quality_flags = TRUE)

      acs_data <- define_extract_micro(
        collection  = "usa",
        description = extract_name,
        samples     = paste0("us", y, "a"),
        variables   = list(
          # Identifiers
          "YEAR", "SAMPLE", "SERIAL", "HHWT", "PERWT", "CLUSTER", "STRATA",
          "CPI99", "STATEFIP", "COUNTYFIP", "FOODSTMP",
          # Person identifiers and relationships
          "PERNUM", "MOMLOC", "POPLOC", "SPLOC", "MOMLOC2", "POPLOC2",
          "RELATED", "NCHILD", "YNGCH",
          # Demographics
          "AGE", "SEX", "RACE", "HISPAN", "MARST", "CITIZEN", "SCHOOL", "EDUCD",
          # Group quarters
          gq,
          # Employment variables
          workedyr, empstat, empstatd, classwkr, wkswork2, uhrswork, labforce,
          # Income variables
          inctot, incwage, incbus00, incearn, incinvst, incwelfr, incsupp, incother
        )
      ) |>
        submit_extract() |>
        wait_for_extract() |>
        download_extract(download_dir = dir_data_acs, overwrite = overwrite_extract_files) |>
        read_ipums_micro() |>
        rename_with(tolower)

      # Write CSV for Stata import
      utils::write.csv(acs_data, file_acs, row.names = FALSE)

      rm(acs_data)
      gc()

    } else {
      message("Skipping ", y, " (CSV exists and overwrite_csv=FALSE): ", file_acs)
    }
  }

  invisible(TRUE)
}

# ---- Execute if called from Stata via rcall ----
if (exists("project_root") && exists("dir_data_acs") && exists("api_codes_path")) {
  download_ipums_acs(
    project_root   = project_root,
    dir_data_acs   = dir_data_acs,
    api_codes_path = api_codes_path,
    start_year     = start_year,
    end_year       = end_year,
    overwrite_csv  = overwrite_csv
  )
}
