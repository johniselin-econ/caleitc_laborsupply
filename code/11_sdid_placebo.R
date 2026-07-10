# =============================================================================
# File:    11_sdid_placebo.R
# Purpose: State-level placebo (randomization) inference for the stage-13
#          weighted county SDID headline (10_sdid.R). The county
#          bootstrap in 03 resamples units, but CalEITC treatment is assigned
#          at the STATE level; this script builds the placebo-in-space
#          reference distribution at that level: for each donor state s, its
#          counties become the pseudo-treated block (treated.weights = that
#          state's 2010 county populations, exactly as CA's) and the joint
#          weighted SDID is refit with an otherwise identical design.
#
#          Conventions (PLAN_inference_litreview.md; author decision
#          2026-07-07):
#            - CA stays in the donor pool of placebo refits (as untreated),
#              mirroring the RIWB convention: the placebo statistic must come
#              from the same design as the actual one (Lehmann-Romano
#              symmetry), permuting only which state carries the treated
#              label.
#            - Exhaustive enumeration over the donor states present in the
#              cell's NA-filtered panel (27 expected). No sampling, no RNG —
#              the whole script is deterministic.
#            - Reference distribution is placebo-only; two-sided RI p-value
#              with the +1 convention: p = (1 + #{|T_s| >= |T_CA|}) / (S + 1).
#              With 27 donor states the attainable floor is 1/28 ~ 0.036.
#            - Two test statistics, both reported (open author decision):
#              raw ATT, and ATT / pre-RMSPE (ADH-style scaling; pre-RMSPE =
#              RMS of the lambda-demeaned treated-minus-synthetic gap over
#              pre-periods, computed on the covariate-adjusted outcome
#              Y - X.beta so cov specs are scaled by the estimator's own
#              pre-fit).
#          The placebo sd is included for reference only — the fork's MC
#          shows placebo SEs under-cover under weight concentration
#          (PLAN.md §D); the RI p-value is the inference object.
#
# Inputs:  data/interim/sdid_county_panel_r.rds (stage 10; rebuilt from the
#          working file if missing), the synthdid_weights fork sourced from
#          cfg$synthdid_dir (default: sibling ../synthdid_weights).
# Output:  data/tmp/sdid_county_stateplacebo_r.csv — one row per outcome x
#          spec with the actual ATT, p-values, and placebo-distribution
#          summaries; companion .rds adds the full per-state placebo detail
#          (state, ATT, pre-RMSPE, county count). Under SLURM_ARRAY_TASK_ID
#          k (1-12, same grid order as 03) only that cell runs and files get
#          a _task<k> suffix.
#
# Usage:   Rscript code/11_sdid_placebo.R   # serial, or 12-task
#          array via code/hpc/stage14_sdid_stateplacebo.sbatch. Each cell is
#          1 actual + ~27 placebo full fits (no bootstrap), so cov cells cost
#          ~28 joint-beta optimizations — minutes, not the hours of stage 13.
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
suppressPackageStartupMessages(library(dplyr))

## Load the fork (their scripts source R/*.R directly; base R + mvtnorm) -------
synthdid_dir <- cfg$synthdid_dir %||% file.path(dirname(repo_root),
                                                "synthdid_weights")
stopifnot(dir.exists(file.path(synthdid_dir, "R")))
invisible(lapply(list.files(file.path(synthdid_dir, "R"),
                            pattern = "[.][Rr]$", full.names = TRUE), source))

## Panel ------------------------------------------------------------------------
panel_rds <- path_data("interim", "sdid_county_panel_r.rds")
if (file.exists(panel_rds)) {
  panel <- readRDS(panel_rds)
} else {
  source(file.path("code", "lib", "sdid_panel.R"))
  wf <- readRDS(path_data("final", "acs_working_file_r.rds"))
  panel <- build_sdid_county_panel(wf)
  saveRDS(panel, panel_rds)
  rm(wf); invisible(gc())
}
message("Panel: ", nrow(panel), " rows, ",
        length(unique(panel$fips)), " units, years ",
        min(panel$year), "-", max(panel$year))

OUTCOMES <- c("employed_y", "full_time_y", "part_time_y")
SPECS <- list(
  basic      = list(ysuf = "",      xcols = NULL),
  basic_cov  = list(ysuf = "",      xcols = c("unemp1", "minwage1")),
  triple     = list(ysuf = "_diff", xcols = NULL),
  triple_cov = list(ysuf = "_diff", xcols = c("unemp", "minwage"))
)
TREAT_YR   <- 2015
TREAT_FIPS <- 6

GRID <- expand.grid(sp = names(SPECS), out = OUTCOMES,
                    stringsAsFactors = FALSE)[, c("out", "sp")]
task <- suppressWarnings(as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID")))
if (!is.na(task)) stopifnot(task >= 1, task <= nrow(GRID))

# NA-filter the panel for one cell. The drop is assignment-independent (it
# depends only on the columns the spec needs), so every placebo refit within
# a cell shares this data frame and differs only in the treated label. A
# dropped CA county still aborts — the actual estimand would change.
cell_df <- function(panel, ycol, xcols) {
  need <- c(ycol, xcols)
  bad <- sort(unique(panel$fips[!complete.cases(panel[, need, drop = FALSE])]))
  if (length(bad)) {
    bad_treated <- unique(panel$fips[panel$state_fips == TREAT_FIPS]) |>
      intersect(bad)
    if (length(bad_treated))
      stop("treated units dropped for NA in ", paste(need, collapse = "/"),
           ": fips ", paste(bad_treated, collapse = ", "))
    message("  dropping ", length(bad), " donor unit(s) with NA in ",
            paste(need, collapse = "/"))
    panel <- panel[!(panel$fips %in% bad), ]
  }
  panel
}

# One joint weighted SDID with treat_state's counties as the treated block.
# Everything else — donor pool (all other counties, CA's included when
# treat_state != 6), covariates, 2010-pop treated weights — mirrors the
# actual fit. Alignment by rownames(Y): panel.matrices orders controls-first,
# each block sorted by unit id.
fit_state <- function(df, ycol, xcols, treat_state) {
  dfp <- data.frame(.unit = df$fips, .time = df$year,
                    y = df[[ycol]],
                    .W = as.integer(df$state_fips == treat_state &
                                      df$year >= TREAT_YR))
  setup <- panel.matrices(dfp)

  base_yr <- min(df$year)
  pop_map <- with(df[df$year == base_yr, ],
                  setNames(pop, as.character(fips)))
  units <- rownames(setup$Y)
  treated_units <- units[(setup$N0 + 1):nrow(setup$Y)]
  tw <- as.numeric(pop_map[treated_units])
  stopifnot(!anyNA(tw), all(tw > 0))

  X <- NULL
  if (length(xcols)) {
    X <- array(NA_real_, dim = c(nrow(setup$Y), ncol(setup$Y), length(xcols)),
               dimnames = list(units, colnames(setup$Y), xcols))
    for (k in seq_along(xcols)) {
      m <- tapply(df[[xcols[k]]],
                  list(as.character(df$fips), as.character(df$year)),
                  identity)
      X[, , k] <- m[units, colnames(setup$Y)]
    }
    stopifnot(!anyNA(X))
  }

  synthdid_estimate_weighted(setup$Y, setup$N0, setup$T0,
                             treated.weights = tw, X = X)
}

# ADH-style pre-fit scale: RMS of the lambda-demeaned gap between the
# (treated.weights-averaged) treated and (omega-averaged) synthetic
# trajectories over the pre-period, on Y - X.beta so cov specs use the
# estimator's own adjusted outcome. setup$Y stores the raw outcome; beta
# lives in weights$beta (empty for no-cov specs, and contract3 of a
# zero-covariate array is a zero matrix).
pre_rmspe <- function(est) {
  setup <- attr(est, "setup")
  w     <- attr(est, "weights")
  tw    <- attr(est, "treated.weights")
  N0 <- setup$N0
  T0 <- setup$T0
  Yadj <- setup$Y - contract3(setup$X, w$beta)
  tr  <- colSums(Yadj[(N0 + 1):nrow(Yadj), , drop = FALSE] * tw)
  syn <- colSums(Yadj[1:N0, , drop = FALSE] * w$omega)
  gap <- (tr - syn)[1:T0]
  sqrt(mean((gap - sum(w$lambda * gap))^2))
}

## Estimation -------------------------------------------------------------------
summ   <- list()
detail <- list()

for (gi in if (is.na(task)) seq_len(nrow(GRID)) else task) {
  out   <- GRID$out[gi]
  sp    <- GRID$sp[gi]
  ycol  <- paste0(out, SPECS[[sp]]$ysuf)
  xcols <- SPECS[[sp]]$xcols
  message(sprintf("=== %s | %s (Y = %s%s) ===", out, sp, ycol,
                  if (length(xcols))
                    paste0(", X = ", paste(xcols, collapse = "+"))
                  else ""))
  df <- cell_df(panel, ycol, xcols)
  donor_states <- sort(setdiff(unique(df$state_fips), TREAT_FIPS))
  n_cty <- table(df$state_fips[df$year == min(df$year)])

  fit_row <- function(ss, label) {
    est <- fit_state(df, ycol, xcols, ss)
    data.frame(outcome = out, spec = sp, state_fips = ss, role = label,
               att = as.numeric(est), pre_rmspe = pre_rmspe(est),
               n_treated = as.integer(n_cty[as.character(ss)]))
  }

  actual <- fit_row(TREAT_FIPS, "actual")
  message(sprintf("  actual   CA (%2d counties)  ATT %8.3f  preRMSPE %.4f",
                  actual$n_treated, actual$att, actual$pre_rmspe))

  placebo <- lapply(donor_states, function(ss) {
    row <- tryCatch(fit_row(ss, "placebo"), error = function(e) {
      message(sprintf("  placebo state %2d FAILED: %s", ss, conditionMessage(e)))
      NULL
    })
    if (!is.null(row))
      message(sprintf("  placebo %2d (%2d counties)  ATT %8.3f  preRMSPE %.4f",
                      row$state_fips, row$n_treated, row$att, row$pre_rmspe))
    row
  })
  placebo <- bind_rows(placebo)
  if (nrow(placebo) < length(donor_states))
    message(sprintf("  NOTE: %d of %d placebo states failed and are excluded",
                    length(donor_states) - nrow(placebo), length(donor_states)))

  # +1 convention, two-sided, placebo-only reference distribution
  ri_p <- function(t0, ts) (1 + sum(abs(ts) >= abs(t0))) / (1 + length(ts))
  p_raw   <- ri_p(actual$att, placebo$att)
  p_rmspe <- ri_p(actual$att / actual$pre_rmspe,
                  placebo$att / placebo$pre_rmspe)

  summ[[length(summ) + 1]] <- data.frame(
    outcome = out, spec = sp,
    att = actual$att, pre_rmspe = actual$pre_rmspe,
    p_ri_raw = p_raw, p_ri_rmspe = p_rmspe,
    placebo_sd = sd(placebo$att),
    placebo_mean = mean(placebo$att),
    n_placebo = nrow(placebo), n_donor_states = length(donor_states))
  detail[[length(detail) + 1]] <- bind_rows(actual, placebo)

  message(sprintf("  => p_RI(raw) = %.4f   p_RI(rmspe-scaled) = %.4f   (S = %d)",
                  p_raw, p_rmspe, nrow(placebo)))
}

summ   <- bind_rows(summ)
detail <- bind_rows(detail)
suffix <- if (is.na(task)) "" else sprintf("_task%d", task)
write.csv(summ,
          path_data("tmp", paste0("sdid_county_stateplacebo_r", suffix, ".csv")),
          row.names = FALSE)
saveRDS(list(summary = summ, detail = detail),
        path_data("tmp", paste0("sdid_county_stateplacebo_r", suffix, ".rds")))

message("\n=== Summary (state-level placebo RI) ===")
print(summ |>
        mutate(across(c(att, placebo_sd), \(x) round(x, 3)),
               across(c(p_ri_raw, p_ri_rmspe), \(x) round(x, 4))) |>
        select(outcome, spec, att, placebo_sd, p_ri_raw, p_ri_rmspe,
               n_placebo),
      row.names = FALSE)
message("SDID STATE-PLACEBO INFERENCE COMPLETE (",
        nrow(summ), " cells, ", nrow(detail), " fits)")
