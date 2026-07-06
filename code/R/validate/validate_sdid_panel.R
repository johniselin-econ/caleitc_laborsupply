# =============================================================================
# File:    validate_sdid_panel.R
# Purpose: Row-for-row validation of the R-built SDID county panel
#          (code/R/utils/sdid_panel.R) against Stata's
#          data/interim/sdid_county_panel.dta (code/hpc/stage10_sdid_panel.do).
#
#          Joins on (state_fips, county_fips, year) and compares every
#          column: integer/indicator columns exactly, real-typed columns to
#          float precision (Stata collapse stores means/sums as float).
#          Also saves the R panel to data/interim/sdid_county_panel_r.rds
#          for the Phase 3 SDID estimation.
#
# Usage:   Rscript code/R/validate/validate_sdid_panel.R   (sbatch; ~48 GB)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
})
source(file.path("code", "R", "utils", "sdid_panel.R"))

message("Loading working file...")
wf <- readRDS(path_data("final", "acs_working_file_r.rds"))

message("Building panel in R...")
r_panel <- build_sdid_county_panel(wf, 2010, 2017)
saveRDS(r_panel, path_data("interim", "sdid_county_panel_r.rds"))
message("R panel: ", nrow(r_panel), " rows x ", ncol(r_panel), " cols")

message("Loading Stata golden panel...")
st_panel <- read_dta(path_data("interim", "sdid_county_panel.dta")) |>
  mutate(across(everything(), as.numeric))

stopifnot(setequal(names(r_panel), names(st_panel)))
stopifnot(nrow(r_panel) == nrow(st_panel))

keys <- c("state_fips", "county_fips", "year")
joined <- inner_join(st_panel, r_panel, by = keys, suffix = c(".st", ".r"))
stopifnot(nrow(joined) == nrow(st_panel))  # key sets identical

exact_cols <- c("fips", "treated", "constant")
float_cols <- setdiff(names(r_panel), c(keys, exact_cols))

fails <- 0
for (col in c(exact_cols, float_cols)) {
  st <- joined[[paste0(col, ".st")]]
  rr <- joined[[paste0(col, ".r")]]
  na_mismatch <- sum(is.na(st) != is.na(rr))
  both <- !is.na(st) & !is.na(rr)
  if (col %in% exact_cols) {
    bad <- sum(st[both] != rr[both])
    tol_txt <- "exact"
  } else if (grepl("_diff$", col)) {
    # diff columns difference two float-stored levels: catastrophic
    # cancellation means the achievable precision is float eps scaled by
    # the LEVELS, not the (small) diff — compare with a component-scaled
    # absolute tolerance
    lvl <- sub("_diff$", "", col)
    scale <- pmax(abs(joined[[paste0(lvl, ".st")]]),
                  abs(joined[[paste0(lvl, "_qc0.st")]]), 1)[both]
    bad <- sum(abs(st[both] - rr[both]) > 5e-7 * scale)
    tol_txt <- "float (level-scaled)"
  } else {
    # Stata collapse output is float: compare at float precision
    rel <- abs(st[both] - rr[both]) / pmax(abs(st[both]), 1e-12)
    bad <- sum(rel > 5e-7)
    tol_txt <- sprintf("max rel %.2e", if (any(both)) max(rel) else 0)
  }
  status <- if (bad + na_mismatch == 0) "OK  " else "FAIL"
  if (bad + na_mismatch > 0) fails <- fails + 1
  message(sprintf("%s %-22s %s | value mismatches: %d | NA-pattern: %d",
                  status, col, tol_txt, bad, na_mismatch))
}

if (fails > 0) stop(fails, " columns failed validation")
message("SDID PANEL VALIDATION PASSED: ", nrow(joined), " rows, ",
        length(exact_cols) + length(float_cols), " columns compared")
