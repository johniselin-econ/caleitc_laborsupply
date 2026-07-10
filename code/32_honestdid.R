# =============================================================================
# File:    32_honestdid.R
# Purpose: PLAN.md par A.6 — Rambachan-Roth (2023) HonestDiD sensitivity on
#          the SDID event studies, using the stage-15 unit-bootstrap
#          replication matrices (job 17232065) to build the full covariance
#          of the event-study path.
#
#          For each outcome x spec: betahat = the 8 SDID event-study
#          estimates (relative time -5..2, T0 = 5 pre periods), sigma = the
#          8x8 covariance of the 500 bootstrap replications. The pre-period
#          coefficients are SDID placebo effects (no omitted reference
#          period); HonestDiD treats them as estimates of the pre-trend
#          violations delta_pre. Target parameter: the average post-period
#          effect (l_vec = 1/3 each).
#            - Relative magnitudes (Delta^RM), Mbar in {0.5, 1, 1.5, 2}:
#              post-period violations bounded by Mbar x the max consecutive
#              pre-period violation. Headline sensitivity.
#            - Smoothness (Delta^SD), M in {0, 0.25, 0.5, 1}: linear-trend
#              deviations up to M pp per period. Secondary.
#          Also reports the original (non-robust) CI and the breakdown Mbar
#          (largest Mbar with robust CI excluding 0).
#
#          Runs on the full-time event studies (all four specs; the paper's
#          attribution question) plus part-time triple (headline outcome,
#          for contrast). Deterministic given the committed stage-15 rds
#          files — no seeds.
#
# Inputs:  results/sdid_r/sdid_county_es_r_task{5,6,7,8,11}.rds (stage 15).
# Output:  results/honestdid/honestdid_sensitivity.csv.
#
# Usage:   Rscript code/32_honestdid.R  (local; needs module GLPK)
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(HonestDiD)
})

TASKS <- c(full_time_y.basic     = 5,  full_time_y.basic_cov = 6,
           full_time_y.triple    = 7,  full_time_y.triple_cov = 8,
           part_time_y.triple    = 11)
MBAR_VEC <- c(0.5, 1, 1.5, 2)
M_SD_VEC <- c(0, 0.25, 0.5, 1)

res <- list()
for (nm in names(TASKS)) {
  es <- readRDS(file.path("results", "sdid_r",
                          sprintf("sdid_county_es_r_task%d.rds", TASKS[nm])))[[nm]]
  stopifnot(identical(es$relative_time, as.numeric(-5:2)),
            attr(es, "T0") == 5)
  betahat <- es$estimate
  reps    <- attr(es, "replications")
  stopifnot(nrow(reps) == 500, ncol(reps) == 8)
  sigma   <- cov(reps)
  n_pre <- 5; n_post <- 3
  l_avg <- rep(1 / n_post, n_post)

  orig <- constructOriginalCS(betahat = betahat, sigma = sigma,
                              numPrePeriods = n_pre, numPostPeriods = n_post,
                              l_vec = l_avg)
  rm_s <- createSensitivityResults_relativeMagnitudes(
    betahat = betahat, sigma = sigma,
    numPrePeriods = n_pre, numPostPeriods = n_post,
    Mbarvec = MBAR_VEC, l_vec = l_avg)
  sd_s <- createSensitivityResults(
    betahat = betahat, sigma = sigma,
    numPrePeriods = n_pre, numPostPeriods = n_post,
    Mvec = M_SD_VEC, l_vec = l_avg)

  res[[nm]] <- bind_rows(
    data.frame(method = "original", M = NA_real_,
               lb = orig$lb, ub = orig$ub),
    data.frame(method = "relative_magnitudes", M = rm_s$Mbar,
               lb = rm_s$lb, ub = rm_s$ub),
    data.frame(method = "smoothness", M = sd_s$M,
               lb = sd_s$lb, ub = sd_s$ub)) |>
    mutate(outcome = sub("[.].*", "", nm), spec = sub(".*[.]", "", nm),
           .before = 1)

  excl0 <- function(l, u) l > 0 | u < 0
  bd <- rm_s |> filter(excl0(lb, ub)) |> pull(Mbar)
  message(sprintf("%-24s avg-post orig [%6.2f, %6.2f]; RM breakdown Mbar %s",
                  nm, orig$lb, orig$ub,
                  if (length(bd)) max(bd) else "< 0.5"))
}
res <- bind_rows(res)

dir.create(file.path("results", "honestdid"), showWarnings = FALSE)
write.csv(res, file.path("results", "honestdid", "honestdid_sensitivity.csv"),
          row.names = FALSE)
message("HONESTDID SENSITIVITY COMPLETE (",
        nrow(res), " rows -> results/honestdid/)")
