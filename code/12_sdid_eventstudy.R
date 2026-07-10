# =============================================================================
# File:    12_sdid_eventstudy.R
# Purpose: Weighted SDID event studies for the Table 2 headline fits
#          (author request 2026-07-07): for each outcome x spec, refit the
#          stage-13 headline variant (joint weighted SDID, treated.weights =
#          2010 county pop, fork joint-beta X) and decompose it with the
#          fork's synthdid_event_study() (Ciccia 2024): lag-specific post
#          effects plus pre-period placebo coefficients (should be ~0 if the
#          synthetic control is well matched). Panel 2010-2017, law 2015 →
#          relative time -5..-1 pre, 0..2 post (2015/16/17).
#
#          Bands: unit-level bootstrap over counties, B = 500 — the same
#          resampling scheme as the stage-13 ATT SEs (state-clustered
#          resampling infeasible with one treated state; no cluster stored
#          on the estimate, so the fork bootstraps units). Replication
#          curves are saved in the .rds (return.replications = TRUE) so the
#          cross-period covariance is available for Rambachan-Roth /
#          HonestDiD sensitivity later (PLAN.md §A.6) without refitting.
#
#          Seeds: params$seed + 200 + <cell index> (201-212; disjoint from
#          stage 13's +1..+120 block), set immediately before the event-study
#          bootstrap. The point estimates are deterministic and must equal
#          the stage-13 weighted ATTs when averaged with the fit's lambda /
#          period weights (the ATT is carried in the CSV as a cross-check).
#
# Inputs:  data/interim/sdid_county_panel_r.rds (stage 10; rebuilt from the
#          working file if missing), the synthdid_weights fork sourced from
#          cfg$synthdid_dir (default: sibling ../synthdid_weights).
# Output:  data/tmp/sdid_county_es_r.csv — one row per outcome x spec x
#          relative_time with estimate/se/ci and the fit's ATT; companion
#          .rds keeps the synthdid_event_study objects incl. the B x T
#          replication matrices. Under SLURM_ARRAY_TASK_ID k (1-12, same
#          grid order as 03) only that cell runs, files get a _task<k>
#          suffix; seeds are per-cell so array == serial.
#
# Usage:   Rscript code/12_sdid_eventstudy.R   # serial, or 12-task array
#          via code/hpc/stage15_sdid_eventstudy.sbatch (cov-spec bootstraps
#          redo the joint-beta optimization per replicate — expect ~stage-13
#          weighted-variant runtimes: minutes no-cov, ~1.5-2h cov)
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
source(file.path("code", "lib", "sdid_setup.R"))

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
B_ES <- 500

# Same grid order as 10_sdid.R (spec fastest within outcome).
GRID <- expand.grid(sp = names(SPECS), out = OUTCOMES,
                    stringsAsFactors = FALSE)[, c("out", "sp")]
task <- suppressWarnings(as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID")))
if (!is.na(task)) stopifnot(task >= 1, task <= nrow(GRID))

## Estimation -------------------------------------------------------------------
res <- list()
es_objs <- list()

for (gi in if (is.na(task)) seq_len(nrow(GRID)) else task) {
  out   <- GRID$out[gi]
  sp    <- GRID$sp[gi]
  ycol  <- paste0(out, SPECS[[sp]]$ysuf)
  xcols <- SPECS[[sp]]$xcols
  message(sprintf("=== %s | %s (Y = %s%s) ===", out, sp, ycol,
                  if (length(xcols))
                    paste0(", X = ", paste(xcols, collapse = "+"))
                  else ""))
  s <- make_setup(panel, ycol, xcols)

  fit <- synthdid_estimate_weighted(
    s$setup$Y, s$setup$N0, s$setup$T0,
    treated.weights = s$treated.weights, X = s$X)
  message(sprintf("  weighted ATT %7.3f (stage-13 cross-check)",
                  as.numeric(fit)))

  seed_i <- params$seed + 200 + gi
  set.seed(seed_i)
  es <- synthdid_event_study(fit, se.method = "bootstrap",
                             replications = B_ES,
                             return.replications = TRUE)

  res[[length(res) + 1]] <- data.frame(
    outcome = out, spec = sp,
    relative_time = es$relative_time,
    year = es$time,
    estimate = es$estimate, se = es$se,
    ci_lower = es$ci_lower, ci_upper = es$ci_upper,
    att = as.numeric(fit), B = B_ES, seed = seed_i)
  es_objs[[paste(out, sp, sep = ".")]] <- es

  print(res[[length(res)]] |>
          mutate(across(c(estimate, se), \(x) round(x, 3))) |>
          select(relative_time, year, estimate, se),
        row.names = FALSE)
}

res <- bind_rows(res)
suffix <- if (is.na(task)) "" else sprintf("_task%d", task)
write.csv(res, path_data("tmp", paste0("sdid_county_es_r", suffix, ".csv")),
          row.names = FALSE)
saveRDS(es_objs,
        path_data("tmp", paste0("sdid_county_es_r", suffix, ".rds")))
message("SDID WEIGHTED EVENT STUDY COMPLETE (",
        length(es_objs), " cells x ", B_ES, " replications)")
