# =============================================================================
# File:    21_altinference_tab.R
# Purpose: Build the appendix Alternative Inference table fragments
#          (tab_appE_tab1_{1,2,3}.tex = employed / full-time / part-time)
#          from the stage-12 R battery (job 17177816) — the appE exhibit
#          integration of PLAN.md Phase 3, replacing the Stata esttab
#          export (04_appE_inference.do). Layout mirrors the committed
#          fragments (booktabs fragment, prehead "\\ \midrule", ATE b(1)
#          se(1) with CRVE stars, p-values %.3f, N with commas) and adds
#          two rows for the placebo-refit procedures:
#            RI P-Value — randomization inference on the coefficient over
#              the 27 identical-design placebo refits (+1 convention;
#              attainable floor 1/28 ~ 0.036), no wild resampling
#            CT 90% CI  — Conley-Taber (2011) interval inverting the same
#              placebo-coefficient distribution (inverse-ECDF quantiles;
#              90% because 95% endpoints with 27 placebos are just the
#              min/max order statistics)
#          Deterministic quantities (ATE/SE/N/CRVE) match the committed
#          job-17058169 Stata tables at display precision (validated,
#          validate_appE_battery.R); resampling p-values are the R
#          battery's draws (inside Bonferroni MC bands vs Stata) and
#          become canonical with this export.
#
# Inputs:  results/appE_r/appE_r_job17177816.csv (staged stage-12 battery;
#          per-task refit detail in the companion appE_r_task*.rds).
# Output:  results/tables/tab_appE_tab1_{1,2,3}.tex, mirrored to
#          results/paper/ (the Overleaf tables/ staging dir). The shell's
#          checkmark footer (tab_main_end.tex) is unchanged.
#
# Usage:   Rscript code/21_altinference_tab.R
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
suppressPackageStartupMessages(library(dplyr))

bat <- read.csv(latest_result("appE_r", "appE_r"))
stopifnot(nrow(bat) == 12, all(bat$N == 461616))

OUTCOMES <- c("employed_y", "full_time_y", "part_time_y")  # panels 1/2/3

stars <- function(p) ifelse(p < 0.01, "\\sym{***}",
                     ifelse(p < 0.05, "\\sym{**}",
                     ifelse(p < 0.10, "\\sym{*}", "")))
fnum <- function(x, d) sprintf(paste0("%.", d, "f"), x)

row_tex <- function(label, cells) {
  paste0(sprintf("%-20s", label),
         paste0("&", sprintf("%22s", cells), collapse = ""), "\\\\")
}

P_ROWS <- c(p_crve     = "  CRVE P-Value",
            p_wcbs     = "  WCBS P-Value",
            p_riwcbs_t = "  RIWB-t P-Value",
            p_riwcbs_b = "  RIWB-b P-Value",
            p_block    = "  BB P-Value",
            p_block_fp = "  Corrected BB P-Value",
            ct_p_ri    = "  RI P-Value")

panel_tex <- function(out) {
  d <- bat |> filter(outcome == out) |> arrange(spec)
  stopifnot(identical(d$spec, 1:4))
  lines <- c(
    "\\\\ \\midrule",
    "\\addlinespace",
    row_tex("ATE", paste0(fnum(d$b, 1), stars(d$p_crve))),
    row_tex("",    sprintf("(%s)", fnum(d$se, 1))),
    "\\addlinespace",
    row_tex("  Observations", formatC(d$N, big.mark = ",", format = "d")))
  for (v in names(P_ROWS))
    lines <- c(lines, row_tex(P_ROWS[[v]], fnum(d[[v]], 3)))
  c(lines,
    row_tex("  CT 90\\% CI",
            sprintf("[%s, %s]", fnum(d$ct_lower, 1), fnum(d$ct_upper, 1))))
}

out_dirs <- c(file.path("results", "tables"), file.path("results", "paper"))
for (i in seq_along(OUTCOMES)) {
  tex <- panel_tex(OUTCOMES[i])
  for (dd in out_dirs)
    writeLines(tex, file.path(dd, sprintf("tab_appE_tab1_%d.tex", i)))
  message("tab_appE_tab1_", i, " (", OUTCOMES[i], "): ", length(tex), " lines")
}
message("APPE TABLE EXPORT COMPLETE")
