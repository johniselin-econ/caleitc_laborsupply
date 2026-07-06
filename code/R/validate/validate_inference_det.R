# =============================================================================
# File:    validate_inference_det.R
# Purpose: Validate the DETERMINISTIC layers of the R inference port
#          (code/R/utils/inference.R) against the stage-11 Stata dumps:
#            - RI refits: b/t for j = 0 (actual) and every placebo j
#            - Ferman-Pinto state-level table (W, q, P, var_M, W_normalized)
#              + alpha_hat
#          for all 12 (outcome x spec) tasks.
#
#          The dumps are float-stored (Stata gen/postfile defaults), so
#          real-valued comparisons use a 1e-5 relative gate and report the
#          max observed relative difference (expected ~1e-7, float storage).
#          Resampling p-values are NOT validated here — they are checked
#          against the job-17058169 golden tables within Monte-Carlo bands
#          when the full R battery runs (stage 12).
#
# Usage:   Rscript code/R/validate/validate_inference_det.R  (sbatch; ~48 GB)
#          Env var APPE_TASKS="1 5 12" restricts to specific tasks.
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
})
source(file.path("code", "R", "utils", "estimation.R"))
source(file.path("code", "R", "utils", "inference.R"))

OUTCOMES <- c("employed_y", "full_time_y", "part_time_y")
task_env <- Sys.getenv("APPE_TASKS", "")
tasks <- if (nzchar(task_env)) as.integer(strsplit(task_env, "\\s+")[[1]]) else 1:12

rel_diff <- function(a, b) abs(a - b) / pmax(abs(a), 1e-12)
TOL <- 1e-5
# Looser, documented gates where float-storage effects stack:
# - t = b/se compounds the ~7e-6 fixest-vs-reghdfe SE agreement (Phase 2)
#   on top of b's ~5e-6 — gate 3e-5;
# - W_did is a signed sum of small terms that the Stata program stores as
#   float at every intermediate step, so cancellation amplifies storage
#   rounding to ~5e-5 (the R port is full double); W_normalized inherits it.
#   b, q, P, var_M, alpha_hat all hold the tight gate. Gate 2e-4.
TOL_T <- 3e-5
TOL_W <- 2e-4

message("Loading working file...")
wf <- readRDS(path_data("final", "acs_working_file_r.rds"))
samp <- appE_sample(wf, 2012, 2017)
rm(wf); invisible(gc())
message("appE sample: ", nrow(samp), " rows (expect 461,616 per golden tables)")

fails <- 0
for (task in tasks) {
  oi <- ceiling(task / 4)
  spec <- task - (oi - 1) * 4
  out <- OUTCOMES[oi]
  message(sprintf("\n=== Task %d: %s spec %d ===", task, out, spec))

  ## --- RI refits ---------------------------------------------------------
  st_ri <- read_dta(path_data("tmp", sprintf("appE_det_ri_task%d.dta", task)))
  r_ri <- appE_ri_refits(out, samp, spec)
  stopifnot(nrow(st_ri) == nrow(r_ri))
  cmp <- inner_join(as.data.frame(st_ri), r_ri, by = "j",
                    suffix = c(".st", ".r"))
  stopifnot(nrow(cmp) == nrow(r_ri),
            all(cmp$state_fips.st == cmp$state_fips.r))
  for (col in c("b", "t")) {
    d <- rel_diff(cmp[[paste0(col, ".st")]], cmp[[paste0(col, ".r")]])
    ok <- max(d) <= if (col == "t") TOL_T else TOL
    if (!ok) fails <- fails + 1
    message(sprintf("%s RI %-4s max rel diff %.2e over %d refits",
                    if (ok) "OK  " else "FAIL", col, max(d), nrow(cmp)))
  }

  ## --- Ferman-Pinto state table ------------------------------------------
  st_fp <- read_dta(path_data("tmp", sprintf("appE_det_fp_task%d.dta", task)))
  r_fp <- appE_fp_prep(out, samp, spec) |>
    rename(W_did = W, P_qjt = P)
  stopifnot(nrow(st_fp) == nrow(r_fp))
  cmp <- inner_join(as.data.frame(st_fp), r_fp, by = "state_fips",
                    suffix = c(".st", ".r"))
  stopifnot(nrow(cmp) == nrow(r_fp))
  for (col in c("ca", "W_did", "q", "P_qjt", "var_M", "W_normalized",
                "alpha_hat")) {
    d <- rel_diff(cmp[[paste0(col, ".st")]], cmp[[paste0(col, ".r")]])
    ok <- max(d) <= if (col %in% c("W_did", "W_normalized")) TOL_W else TOL
    if (!ok) fails <- fails + 1
    message(sprintf("%s FP %-13s max rel diff %.2e",
                    if (ok) "OK  " else "FAIL", col, max(d)))
  }
}

if (fails > 0) stop(fails, " comparisons failed")
message("\nINFERENCE DETERMINISTIC VALIDATION PASSED (tasks: ",
        paste(tasks, collapse = " "), ")")
