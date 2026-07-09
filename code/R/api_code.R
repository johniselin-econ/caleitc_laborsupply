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
  library(yaml)
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
                               extract_desc_prefix = "ACS microdata for CalEITC",
                               acs_source     = NULL,
                               shared_acs_dir = NULL) {

  # Normalize paths (Windows-safe)
  project_root   <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  dir_data_acs   <- normalizePath(dir_data_acs, winslash = "/", mustWork = FALSE)
  api_codes_path <- normalizePath(api_codes_path, winslash = "/", mustWork = FALSE)

  if (!dir.exists(dir_data_acs)) {
    dir.create(dir_data_acs, recursive = TRUE, showWarnings = FALSE)
  }

  setwd(project_root)

  # ---- ACS source toggle -----------------------------------------------------
  # "shared" (default): read the Budget Lab common IPUMS extract from the shared
  # drive. "local": download a fresh per-year extract via the IPUMS API (the
  # original behaviour). Toggle in config/parameters.yaml (acs_source); the
  # shared path lives in config/local_paths.yaml (acs_common_root). Explicit
  # function args win over config.
  if (is.null(acs_source)) {
    cfg_params <- file.path(project_root, "config", "parameters.yaml")
    if (file.exists(cfg_params)) {
      acs_source <- tryCatch(yaml::read_yaml(cfg_params)$acs_source, error = function(e) NULL)
    }
  }
  if (is.null(acs_source) || !nzchar(acs_source)) acs_source <- "shared"
  acs_source <- tolower(acs_source)
  if (!acs_source %in% c("shared", "local")) {
    stop("acs_source must be 'shared' or 'local' (got '", acs_source, "')", call. = FALSE)
  }

  if (identical(acs_source, "shared") && is.null(shared_acs_dir)) {
    cfg_paths <- file.path(project_root, "config", "local_paths.yaml")
    if (file.exists(cfg_paths)) {
      shared_acs_dir <- tryCatch(yaml::read_yaml(cfg_paths)$acs_common_root, error = function(e) NULL)
    }
    if (is.null(shared_acs_dir) || !nzchar(shared_acs_dir)) {
      stop("acs_source='shared' but acs_common_root is not set in config/local_paths.yaml.\n",
           "  Add e.g. acs_common_root: /nfs/roberts/project/pi_nrs36/shared/raw_data/ACS/acs_common\n",
           "  or set acs_source: local in config/parameters.yaml to download instead.", call. = FALSE)
    }
  }
  message("ACS source: ", acs_source,
          if (identical(acs_source, "shared")) paste0("  (", shared_acs_dir, ")") else "")

  # IPUMS key setup (only needed to download in local mode)
  if (identical(acs_source, "local")) {
    ipums_key <- .read_ipums_key(api_codes_path)
    ipumsr::set_ipums_api_key(ipums_key, save = TRUE, overwrite = TRUE)
  }

  # Column contract reproduced when reading the shared (superset) source: the
  # exact per-year schema the local extract produced (lowercased, DDI order).
  # any_of() tolerates IPUMS per-year availability (early years lack some flags),
  # matching what the same variable request yielded for that year.
  acs_keep_cols <- c(
    "year","sample","serial","cbserial","hhwt","cluster","cpi99","statefip",
    "countyfip","strata","gq","foodstmp","pernum","perwt","momloc","poploc",
    "sploc","momloc2","poploc2","nchild","yngch","relate","related","sex","age",
    "marst","race","raced","hispan","hispand","citizen","school","educ","educd",
    "empstat","empstatd","labforce","classwkr","classwkrd","wkswork2","uhrswork",
    "workedyr","inctot","incwage","incbus00","incwelfr","incinvst","incsupp",
    "incother","incearn","qclasswk","qempstat","qocc","quhrswor","qwkswork2",
    "qworkedy","qincearn","qincbus","qincinvs","qincothe","qincreti","qincss",
    "qincsupp","qinctot","qincwage","qincwelf"
  )

  # Years
  years <- seq.int(start_year, end_year)
  if (length(years) == 0) stop("start_year must be <= end_year", call. = FALSE)

  for (y in years) {

    file_acs <- file.path(dir_data_acs, paste0("acs_", y, ".csv"))

    if (!file.exists(file_acs) || isTRUE(overwrite_csv)) {

     if (identical(acs_source, "shared")) {

      message("Reading ACS ", y, " from shared common source...")
      ddi_path <- file.path(shared_acs_dir, paste0("us", y, "a"),
                            paste0("usa_", y, "a.xml"))
      if (!file.exists(ddi_path)) {
        stop("acs_source='shared' but the shared file is missing:\n  ", ddi_path,
             "\n  Fix acs_common_root, or set acs_source: local to download.", call. = FALSE)
      }
      acs_data <- ipumsr::read_ipums_micro(ipumsr::read_ipums_ddi(ddi_path),
                                           verbose = FALSE) |>
        rename_with(tolower) |>
        filter(as.integer(gq) %in% c(1L, 2L)) |>   # reproduce GQ case_selections c("1","2")
        select(any_of(acs_keep_cols))               # reproduce original per-year column set

     } else {

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

     }

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
