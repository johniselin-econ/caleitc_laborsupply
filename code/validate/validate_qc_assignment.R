# =============================================================================
# File:    validate_qc_assignment.R
# Purpose: Row-for-row validation of the qc_assignment R port against the
#          Stata golden dumps produced by code/hpc/stage4_qcdump.do.
#
#          For each validation year: rebuilds the pre-assignment inputs from
#          the raw ACS CSV exactly as 01_clean_data.do Steps 1-2 do, runs the
#          R port, and compares qc_ct / matched / min_qc_age against
#          data/interim/qc_golden_<year>.csv keyed by (serial, pernum).
#          Any mismatch is an error.
#
# Usage:   Rscript code/validate/validate_qc_assignment.R
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
source(file.path("code", "lib", "qc_assignment.R"))

suppressPackageStartupMessages(library(readr))

validate_year <- function(y) {

  message("===== Validating qc_assignment for ", y, " =====")

  golden_file <- path_data("interim", paste0("qc_golden_", y, ".csv"))
  if (!file.exists(golden_file)) {
    stop("Golden file missing: ", golden_file,
         " — run code/hpc/stage4_qcdump.do first.")
  }

  acs <- read_csv(path_data("acs", paste0("acs_", y, ".csv")),
                  col_select = c(serial, pernum, age, school, citizen, marst,
                                 related, momloc, momloc2, poploc, poploc2),
                  show_col_types = FALSE)

  # Mirror 01_clean_data.do Step 1 (single year: hh_id groups on serial)
  inputs <- acs |>
    filter(!is.na(pernum)) |>
    mutate(
      hh_id      = dense_rank(serial),
      qc         = as.integer(((age < 19) | (age < 24 & school == 2)) &
                                (citizen != 3) & !(marst %in% c(1, 2, 3))),
      hoh        = as.integer(related == 101),
      sibling    = as.integer(related == 701),
      foster     = as.integer(related == 1242),
      grandchild = as.integer(related == 901)
    )

  ported <- qc_assignment(inputs)

  golden <- read_csv(golden_file, show_col_types = FALSE)

  stopifnot(nrow(ported) == nrow(golden))

  cmp <- golden |>
    select(serial, pernum, qc_g = qc, age_g = age, qc_ct_g = qc_ct,
           matched_g = matched, min_qc_age_g = min_qc_age) |>
    inner_join(ported |>
                 select(serial, pernum, qc, age, qc_ct, matched, min_qc_age),
               by = c("serial", "pernum"))

  stopifnot(nrow(cmp) == nrow(golden))

  mism <- cmp |>
    summarise(
      qc         = sum(qc != qc_g),
      age        = sum(age != age_g),
      qc_ct      = sum(qc_ct != qc_ct_g),
      matched    = sum(matched != matched_g),
      min_qc_age = sum(coalesce(min_qc_age, -1L) != coalesce(min_qc_age_g, -1L))
    )

  print(as.data.frame(mism))

  if (sum(unlist(mism)) > 0) {
    bad <- cmp |>
      filter(qc_ct != qc_ct_g | matched != matched_g |
               coalesce(min_qc_age, -1L) != coalesce(min_qc_age_g, -1L)) |>
      head(20)
    print(as.data.frame(bad))
    stop("qc_assignment validation FAILED for ", y)
  }

  message("PASS: ", y, " — ", nrow(cmp), " rows identical on qc_ct/matched/min_qc_age")
  invisible(TRUE)
}

for (y in c(2012, 2015)) validate_year(y)

message("===== qc_assignment validation PASSED for all years =====")
