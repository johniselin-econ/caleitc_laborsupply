# =============================================================================
# File:    39_quad_oster_tab.R
# Purpose: Build the tex fragments for the quad-diff and Oster-bounds exhibits
#          (PLAN.md par A / C) from the committed job-tagged R result sets
#          (38_quad_oster.R, job 17562426), reproducing the layout of the Stata
#          golden fragments (results/tables/tab_quad_diff_*.tex,
#          tab_oster_bounds.tex — now R-sourced). Numbers are validated
#          golden-equal in 38_quad_oster.R (64/64 checks).
#
#            tab_quad_diff_{1,2,3}.tex — employed / full-time / part-time
#              panels, 2 specs (FEs only; + demographic controls); rows
#              ATE b\sym{stars} / (SE) / Obs / Adj R2 / pre-period treated mean
#              / implied employment effect.
#            tab_quad_diff_earn.tex    — earnings panel (dollars, no implied).
#            tab_quad_diff_end.tex     — spec-indicator tail (Yes/No rows).
#            tab_oster_bounds.tex      — 4 outcome rows x 8 columns
#              (beta_R, beta_F, R2_R, R2_F, delta*(1.3x), beta_adj(1.3x),
#              delta*(2x), beta_adj(2x)); \midrule before the earnings row.
#
# Inputs:  results/quad_oster/quad_diff_r_job17562426.csv,
#          results/quad_oster/oster_bounds_r_job17562426.csv.
# Output:  results/tables/{tab_quad_diff_{1,2,3,earn,end},tab_oster_bounds}.tex,
#          mirrored to results/paper/.
#
# Usage:   Rscript code/39_quad_oster_tab.R
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
suppressPackageStartupMessages(library(dplyr))

JOB  <- "17562426"
quad <- read.csv(file.path("results", "quad_oster",
                           paste0("quad_diff_r_job", JOB, ".csv")))
ost  <- read.csv(file.path("results", "quad_oster",
                           paste0("oster_bounds_r_job", JOB, ".csv")))

stars <- function(p) ifelse(p < 0.01, "\\sym{***}",
                     ifelse(p < 0.05, "\\sym{**}",
                     ifelse(p < 0.10, "\\sym{*}", "")))
comma <- function(x) formatC(round(x), big.mark = ",", format = "d")
row2  <- function(label, c1, c2, w = 20)
  paste0(sprintf("%-32s", label),
         sprintf("&%*s", w, c1), sprintf("&%*s", w, c2), "\\\\")

## Quad-diff panels --------------------------------------------------------------
# bdig = coefficient/SE decimals (1 for employment pp, 1 for earnings dollars)
quad_panel <- function(out, path, earn = FALSE) {
  d1 <- quad[quad$outcome == out & quad$spec == 1, ]
  d2 <- quad[quad$outcome == out & quad$spec == 2, ]
  bfmt <- function(d) paste0(sprintf("%.1f", d$b), stars(d$p))
  tex <- c("\\\\ \\midrule", "\\addlinespace",
    row2("Quadruple-Diff ATE", bfmt(d1), bfmt(d2)),
    row2("", sprintf("(%.1f)", d1$se), sprintf("(%.1f)", d2$se)),
    "\\addlinespace",
    row2("  Observations", comma(d1$n), comma(d2$n)),
    row2("  Adj. R-Square", sprintf("%.3f", d1$r2a), sprintf("%.3f", d2$r2a)),
    # pre-period mean: dollars (comma, 0 dp) for earnings, else pp (1 dp)
    row2("  Treated group mean in pre-period",
         if (earn) comma(d1$ymean) else sprintf("%.1f", d1$ymean),
         if (earn) comma(d2$ymean) else sprintf("%.1f", d2$ymean)))
  if (!earn)
    tex <- c(tex, row2("  Implied employment effect", comma(d1$C), comma(d2$C)))
  for (dd in c("results/tables", "results/paper"))
    writeLines(tex, file.path(dd, path))
}
quad_panel("employed_y",  "tab_quad_diff_1.tex")
quad_panel("full_time_y", "tab_quad_diff_2.tex")
quad_panel("part_time_y", "tab_quad_diff_3.tex")
quad_panel("incearn_real","tab_quad_diff_earn.tex", earn = TRUE)

# Spec-indicator tail (03_tab_quad_diff.do:144-153)
end_tex <- c("\\\\ \\midrule",
  row2("  Saturated 3-way FEs", "Yes", "Yes"),
  row2("  Add Demographic Controls", "No", "Yes"))
for (dd in c("results/tables", "results/paper"))
  writeLines(end_tex, file.path(dd, "tab_quad_diff_end.tex"))
message("tab_quad_diff_{1,2,3,earn,end} written")

## Oster bounds ------------------------------------------------------------------
LAB <- c(employed_y = "Employed", full_time_y = "Full-time",
         part_time_y = "Part-time", incearn_real = "Earnings (\\$)")
dfmt <- function(x) ifelse(is.na(x), "$\\infty$", sprintf("%.2f", x))
oster_row <- function(o) {
  r <- ost[ost$outcome == o, ]
  bd <- if (o == "incearn_real") "%.1f" else "%.3f"    # coefficient decimals
  cells <- c(sprintf(bd, r$beta_R), sprintf(bd, r$beta_F),
             sprintf("%.3f", r$R2_R), sprintf("%.3f", r$R2_F),
             dfmt(r$delta_13), sprintf(bd, r$beta_adj_13),
             dfmt(r$delta_2R), sprintf(bd, r$beta_adj_2R))
  paste0(LAB[[o]], " & ", paste(sprintf("%9s", cells), collapse = " & "), " \\\\")
}
oster_tex <- c(oster_row("employed_y"), oster_row("full_time_y"),
               oster_row("part_time_y"), "\\midrule",
               oster_row("incearn_real"))
for (dd in c("results/tables", "results/paper"))
  writeLines(oster_tex, file.path(dd, "tab_oster_bounds.tex"))
message("tab_oster_bounds written")
message("QUAD + OSTER TABLE EXPORT COMPLETE")
