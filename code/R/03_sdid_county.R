# =============================================================================
# File:    03_sdid_county.R
# Purpose: Re-estimate the paper's SDID Table 2 (county-level) on the
#          synthdid_weights fork — the Phase 3 methodology change approved
#          2026-07-04: ONE joint weighted SDID with treated.weights = 2010
#          county population, replacing sdid_wt.do's per-county-loop
#          estimator (fit per treated county, ATTs averaged by 2010 pop).
#          Numbers are a re-estimation, not a golden-file replication.
#
#          Specs per outcome, in the CODE order of 03_sdid_county.do:246-287
#          (the paper's printed headers are misordered — see PLAN.md §D):
#            1 basic      Y = <out>        (QC-present level),  no covariates
#            2 basic_cov  Y = <out>,        X = unemp1, minwage1
#            3 triple     Y = <out>_diff   (QC1 - QC0 within county-year)
#            4 triple_cov Y = <out>_diff,   X = unemp, minwage (pop-weighted)
#
#          Variants per spec (PLAN.md §D: report a range — the fork's own
#          ACA results warn that pop-weighted county SDID can fail in-time
#          placebos via size-correlated trends):
#            weighted   — headline: joint fit, treated.weights = 2010 pop
#            unweighted — equal treated weights (reference)
#            detrend    — per-unit pre-period linear trend removed
#                         (no-cov specs only: the fork forbids detrend + X)
#            stratified — size-binned donor pools, 2010-pop quartile strata
#                         (no-cov specs only: X passthrough inside strata
#                         is unverified in the fork)
#            intime     — placebo law in 2013 estimated on 2010-2014 data
#                         only (T0 = 3, T1 = 2; true post period excluded)
#
#          Inference: unit-level bootstrap over counties (PLAN.md §D:
#          state-clustered resampling is infeasible with one treated state;
#          unit bootstrap is like-for-like with the old Stata block
#          bootstrap), B = 500 (the paper note's count — the old code ran
#          an unseeded B = 100), seeded per fit via set.seed (the fork's
#          vcov has no seed argument and draws from the global RNG).
#
#          Covariates enter the fork's joint-beta X handling — NOT Stata
#          sdid's covariates(, projected); coefficients differ by design.
#
# Inputs:  data/interim/sdid_county_panel_r.rds (stage 10, validated
#          row-for-row against the Stata golden panel; rebuilt from the
#          working file if missing), the synthdid_weights fork sourced from
#          cfg$synthdid_dir (default: sibling ../synthdid_weights).
# Output:  data/tmp/sdid_county_r.csv (+ .rds with per-fit detail) — one
#          row per outcome x spec x variant. Under SLURM_ARRAY_TASK_ID k
#          (1-12, outcome x spec in loop order) only that cell runs and
#          files get a _task<k> suffix; seeds are identical either way
#          (per-cell offset, not cumulative). Table/tex export follows once
#          the author signs off on the range (PLAN.md §D).
#
# Usage:   Rscript code/R/03_sdid_county.R   # serial, or 12-task array via
#          code/hpc/stage13_sdid_county.sbatch (cov-spec bootstraps redo the
#          joint-beta optimization per replicate — hours per variant)
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))
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
  source(file.path("code", "R", "utils", "sdid_panel.R"))
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
B_SDID    <- 500
TREAT_YR  <- 2015

# Outcome x spec grid in loop order (spec fastest). SLURM_ARRAY_TASK_ID
# picks one row; unset runs the whole grid serially.
GRID <- expand.grid(sp = names(SPECS), out = OUTCOMES,
                    stringsAsFactors = FALSE)[, c("out", "sp")]
task <- suppressWarnings(as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID")))
if (!is.na(task)) stopifnot(task >= 1, task <= nrow(GRID))

# panel.matrices setup + aligned pop weights / covariate array / strata.
# Units with any NA in the columns a spec needs are dropped (with a loud
# message; a dropped TREATED unit aborts — the estimand would change).
make_setup <- function(panel, ycol, xcols = NULL,
                       end_year = NULL, treat_year = TREAT_YR) {
  df <- panel
  if (!is.null(end_year)) df <- df[df$year <= end_year, ]
  need <- c(ycol, xcols)
  bad <- sort(unique(df$fips[!complete.cases(df[, need, drop = FALSE])]))
  if (length(bad)) {
    bad_treated <- unique(df$fips[df$state_fips == 6]) |> intersect(bad)
    if (length(bad_treated))
      stop("treated units dropped for NA in ", paste(need, collapse = "/"),
           ": fips ", paste(bad_treated, collapse = ", "))
    message("  dropping ", length(bad), " donor unit(s) with NA in ",
            paste(need, collapse = "/"))
    df <- df[!(df$fips %in% bad), ]
  }
  dfp <- data.frame(.unit = df$fips, .time = df$year,
                    y = df[[ycol]],
                    .W = as.integer(df$state_fips == 6 &
                                      df$year >= treat_year))
  setup <- panel.matrices(dfp)

  # Alignment by rownames(Y) — panel.matrices orders controls-first, each
  # block sorted by unit id; never assume input order.
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

  pop_all <- as.numeric(pop_map[units])
  strata <- cut(pop_all, quantile(pop_all, 0:4 / 4),
                include.lowest = TRUE, labels = FALSE)

  list(setup = setup, X = X, treated.weights = tw, strata = strata,
       n_dropped = length(bad), base_yr = base_yr)
}

## Estimation -------------------------------------------------------------------
res <- list()
fits <- list()
fit_i <- 0

run_fit <- function(est, tag) {
  fit_i <<- fit_i + 1
  seed_i <- params$seed + fit_i
  set.seed(seed_i)
  se <- sqrt(vcov(est, method = "bootstrap", replications = B_SDID))
  data.frame(att = as.numeric(est), se = as.numeric(se),
             B = B_SDID, seed = seed_i)
}

for (gi in if (is.na(task)) seq_len(nrow(GRID)) else task) {
  {
    out   <- GRID$out[gi]
    sp    <- GRID$sp[gi]
    # Per-cell seed block (<= 5 fits per cell), so array and serial runs
    # draw identical seeds for the same (outcome, spec).
    fit_i <- (gi - 1) * 10
    ycol  <- paste0(out, SPECS[[sp]]$ysuf)
    xcols <- SPECS[[sp]]$xcols
    message(sprintf("=== %s | %s (Y = %s%s) ===", out, sp, ycol,
                    if (length(xcols))
                      paste0(", X = ", paste(xcols, collapse = "+"))
                    else ""))
    s <- make_setup(panel, ycol, xcols)
    N1 <- nrow(s$setup$Y) - s$setup$N0

    variants <- list()
    variants$weighted <- synthdid_estimate_weighted(
      s$setup$Y, s$setup$N0, s$setup$T0,
      treated.weights = s$treated.weights, X = s$X)
    variants$unweighted <- synthdid_estimate_weighted(
      s$setup$Y, s$setup$N0, s$setup$T0, X = s$X)
    if (is.null(xcols)) {
      variants$detrend <- synthdid_estimate_weighted(
        s$setup$Y, s$setup$N0, s$setup$T0,
        treated.weights = s$treated.weights, detrend = TRUE)
      variants$stratified <- synthdid_estimate_stratified(
        s$setup$Y, s$setup$N0, s$setup$T0, strata = s$strata,
        treated.weights = s$treated.weights, drop.infeasible = TRUE)
    }
    # In-time placebo: fake 2013 law, 2010-2014 data only (no true post years)
    s_pl <- make_setup(panel, ycol, xcols, end_year = 2014, treat_year = 2013)
    variants$intime <- synthdid_estimate_weighted(
      s_pl$setup$Y, s_pl$setup$N0, s_pl$setup$T0,
      treated.weights = s_pl$treated.weights, X = s_pl$X)

    for (v in names(variants)) {
      st <- run_fit(variants[[v]], paste(out, sp, v))
      message(sprintf("  %-11s ATT %7.3f (SE %.3f)", v, st$att, st$se))
      res[[length(res) + 1]] <- cbind(
        data.frame(outcome = out, spec = sp, variant = v,
                   N0 = if (v == "intime") s_pl$setup$N0 else s$setup$N0,
                   N1 = N1,
                   n_dropped = if (v == "intime") s_pl$n_dropped
                               else s$n_dropped),
        st)
      fits[[paste(out, sp, v, sep = ".")]] <- variants[[v]]
    }
  }
}

res <- bind_rows(res)
suffix <- if (is.na(task)) "" else sprintf("_task%d", task)
write.csv(res, path_data("tmp", paste0("sdid_county_r", suffix, ".csv")),
          row.names = FALSE)
saveRDS(list(results = res,
             strata_tables = lapply(
               fits[grepl("stratified", names(fits))],
               \(f) attr(f, "strata.table"))),
        path_data("tmp", paste0("sdid_county_r", suffix, ".rds")))

message("\n=== Summary (ATT, weighted headline vs old Table 2 order) ===")
print(res |>
        filter(variant %in% c("weighted", "detrend", "stratified", "intime")) |>
        mutate(across(c(att, se), \(x) round(x, 2))) |>
        select(outcome, spec, variant, att, se),
      row.names = FALSE)
message("SDID COUNTY RE-ESTIMATION COMPLETE (", nrow(res), " fits)")
