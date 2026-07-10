# =============================================================================
# File:    35_robustness_tab.R
# Purpose: Build the tex fragments for the Phase 3 robustness exhibits
#          (PLAN.md par A.3 / A.5 / A.6) from the committed job-tagged
#          result sets:
#            tab_medicaid_{1,2,3}.tex   — Medicaid-expansion control pool
#              triple-diff (stage 17), panels employed/FT/PT x 4 nested
#              specs, cells b\sym{stars} / (se), CRVE state-clustered
#              (11 clusters; stars follow the main-table convention).
#            tab_alt_threshold_{1,2}.tex — alternative FT thresholds
#              (stage 17), panel 1 = 31-hour, panel 2 = 39-hour, rows
#              FT/PT x 4 specs.
#            tab_honestdid_{1,2}.tex    — Rambachan-Roth sensitivity
#              (32_honestdid.R), panel 1 = relative magnitudes, panel 2 =
#              smoothness; columns FT basic/basic+cov/triple/triple+cov,
#              PT triple; cells [lb, ub] for the average post-period
#              effect.
#          Spec-checkmark tail rows reuse tables/tab_main_end.
#
# Inputs:  results/robustness/robustness_medicaid_job17253645.csv,
#          results/robustness/robustness_altthresh_job17253645.csv,
#          results/honestdid/honestdid_sensitivity.csv.
# Output:  results/tables/tab_{medicaid_{1,2,3},alt_threshold_{1,2},
#          honestdid_{1,2}}.tex, mirrored to results/paper/.
#
# Usage:   Rscript code/35_robustness_tab.R
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
suppressPackageStartupMessages(library(dplyr))

med <- read.csv(file.path("results", "robustness",
                          "robustness_medicaid_job17253645.csv"))
alt <- read.csv(file.path("results", "robustness",
                          "robustness_altthresh_job17253645.csv"))
hon <- read.csv(file.path("results", "honestdid",
                          "honestdid_sensitivity.csv"))

stars <- function(p) ifelse(p < 0.01, "\\sym{***}",
                     ifelse(p < 0.05, "\\sym{**}",
                     ifelse(p < 0.10, "\\sym{*}", "")))
row_tex <- function(label, cells, w = 24) {
  paste0(sprintf("%-28s", label),
         paste0("&", sprintf(paste0("%", w, "s"), cells), collapse = ""),
         "\\\\")
}

## Medicaid pool: one fragment per outcome ---------------------------------------
coef_block <- function(d, label) {
  d <- d |> arrange(spec)
  stopifnot(nrow(d) == 4)
  c(row_tex(label, paste0(sprintf("%.2f", d$b), stars(d$p))),
    row_tex("", sprintf("(%.2f)", d$se)))
}
for (i in seq_along(c("employed_y", "full_time_y", "part_time_y"))) {
  out <- c("employed_y", "full_time_y", "part_time_y")[i]
  d <- med |> filter(outcome == out)
  tex <- c("\\\\ \\midrule", "\\addlinespace",
           coef_block(d, "ATE"),
           "\\addlinespace",
           row_tex("Observations",
                   rep(formatC(d$n[1], big.mark = ","), 4)),
           row_tex("Control states", rep(d$G[1] - 1, 4)))
  for (dd in c("results/tables", "results/paper"))
    writeLines(tex, file.path(dd, sprintf("tab_medicaid_%d.tex", i)))
}
message("tab_medicaid_{1,2,3} written")

## Alt thresholds: one fragment per threshold ------------------------------------
for (i in seq_along(c(31, 39))) {
  th <- c(31, 39)[i]
  ft <- alt |> filter(outcome == sprintf("full_time_y_%d", th))
  pt <- alt |> filter(outcome == sprintf("part_time_y_%d", th))
  tex <- c("\\\\ \\midrule", "\\addlinespace",
           coef_block(ft, sprintf("Full-time (%d+ hours)", th)),
           coef_block(pt, sprintf("Part-time ($<$%d hours)", th)),
           "\\addlinespace",
           row_tex("Observations",
                   rep(formatC(ft$n[1], big.mark = ","), 4)))
  for (dd in c("results/tables", "results/paper"))
    writeLines(tex, file.path(dd, sprintf("tab_alt_threshold_%d.tex", i)))
}
message("tab_alt_threshold_{1,2} written")

## HonestDiD: RM and smoothness panels -------------------------------------------
COLS <- tibble::tribble(
  ~outcome,      ~spec,
  "full_time_y", "basic",
  "full_time_y", "basic_cov",
  "full_time_y", "triple",
  "full_time_y", "triple_cov",
  "part_time_y", "triple")
ci_cells <- function(method_, M_) {
  sapply(seq_len(nrow(COLS)), function(j) {
    d <- hon |> filter(outcome == COLS$outcome[j], spec == COLS$spec[j],
                       method == method_,
                       if (is.na(M_)) is.na(M) else M == M_)
    stopifnot(nrow(d) == 1)
    sprintf("[%.2f, %.2f]", d$lb, d$ub)
  })
}
rm_rows <- c(row_tex("Original 95\\% CI", ci_cells("original", NA), 18),
             "\\addlinespace",
             sapply(c(0.5, 1, 1.5, 2), function(m)
               row_tex(sprintf("$\\bar{M} = %.1f$", m),
                       ci_cells("relative_magnitudes", m), 18)))
sd_rows <- c(row_tex("Original 95\\% CI", ci_cells("original", NA), 18),
             "\\addlinespace",
             sapply(c(0, 0.25, 0.5, 1), function(m)
               row_tex(sprintf("$M = %.2f$", m),
                       ci_cells("smoothness", m), 18)))
for (dd in c("results/tables", "results/paper")) {
  writeLines(c("\\\\ \\midrule", "\\addlinespace", rm_rows),
             file.path(dd, "tab_honestdid_1.tex"))
  writeLines(c("\\\\ \\midrule", "\\addlinespace", sd_rows),
             file.path(dd, "tab_honestdid_2.tex"))
}
message("tab_honestdid_{1,2} written")
message("ROBUSTNESS TABLES EXPORT COMPLETE")
