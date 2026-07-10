# =============================================================================
# File:    13_sdid_tab.R
# Purpose: Build the paper's Table 2 (SDID) tex fragments from the stage-13
#          county estimates and stage-14 state-placebo RI p-values, per the
#          author decisions of 2026-07-07 (PLAN.md Phase 3 step 2):
#            - headline row: weighted joint fit, ATT / (unit-bootstrap SE) /
#              [RMSPE-scaled RI p]; no significance stars — the RI p-value
#              is the inference object (bootstrap SEs under-cover, fork MC)
#            - robustness rows: in-time placebo (all specs), detrended and
#              size-stratified (no-covariate specs only, fork constraints)
#            - columns in the CODE order of 03_sdid_county.do: Basic /
#              Basic+Cov / Triple / Triple+Cov (the old paper header row was
#              misordered relative to the fragments; fixed in main_aejep.tex
#              alongside this export)
#          Fragment layout mirrors the old esttab output (booktabs fragment,
#          prehead "\\ \midrule", b(2) se(2), N with commas) so the paper's
#          tabular shell needs no structural changes.
#
# Inputs:  results/sdid_r/sdid_county_r_job17203764.csv (stage 13),
#          results/sdid_r/sdid_county_stateplacebo_r_job17220617.csv
#          (stage 14) — the committed job-tagged result sets.
# Output:  results/tables/tab_sdid_county_{1,2,3}.tex (employed / full-time /
#          part-time panels) + tab_sdid_county_end.tex (spec checkmarks),
#          mirrored to results/paper/ (the Overleaf tables/ staging dir).
#
# Usage:   Rscript code/13_sdid_tab.R
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
suppressPackageStartupMessages(library(dplyr))

county <- read.csv(file.path("results", "sdid_r",
                             "sdid_county_r_job17203764.csv"))
plac   <- read.csv(file.path("results", "sdid_r",
                             "sdid_county_stateplacebo_r_job17220617.csv"))

OUTCOMES <- c("employed_y", "full_time_y", "part_time_y")  # panels 1/2/3
SPECS    <- c("basic", "basic_cov", "triple", "triple_cov")  # cols (1)-(4)
N_OBS    <- 1928  # 241 units x 2010-2017 (asserted below)

stopifnot(all(county$N0 + county$N1 == 241), all(county$n_dropped == 0))

fmt  <- function(x) ifelse(is.na(x), "", sprintf("%.2f", x))
pfmt <- function(x) ifelse(is.na(x), "", sprintf("[%.3f]", x))

# One table row: label & c1 & c2 & c3 & c4 \\
row_tex <- function(label, cells) {
  paste0(sprintf("%-16s", label),
         paste0("&", sprintf("%20s", cells), collapse = ""), "\\\\")
}

# Pull (att, se) vectors across the four specs for one outcome x variant.
pull_var <- function(out, var) {
  d <- county |>
    filter(outcome == out, variant == var) |>
    arrange(match(spec, SPECS))
  full <- d[match(SPECS, d$spec), ]  # NA rows where the variant wasn't run
  list(att = full$att, se = full$se)
}

panel_tex <- function(out) {
  w  <- pull_var(out, "weighted")
  it <- pull_var(out, "intime")
  dt <- pull_var(out, "detrend")
  st <- pull_var(out, "stratified")
  p  <- plac |> arrange(match(spec, SPECS)) |>
    filter(outcome == out) |> pull(p_ri_rmspe)
  stopifnot(length(p) == 4, !anyNA(w$att), !anyNA(it$att))

  c("\\\\ \\midrule",
    paste0("            ",
           paste0(sprintf("&\\multicolumn{1}{c}{(%d)}", 1:4), collapse = ""),
           "\\\\"),
    "\\addlinespace",
    row_tex("ATT",  fmt(w$att)),
    row_tex("",     sprintf("(%s)", fmt(w$se))),
    row_tex("",     pfmt(p)),
    "\\addlinespace",
    row_tex("In-time placebo", fmt(it$att)),
    row_tex("",     sprintf("(%s)", fmt(it$se))),
    row_tex("Detrended", fmt(dt$att)),
    row_tex("",     ifelse(is.na(dt$se), "", sprintf("(%s)", fmt(dt$se)))),
    row_tex("Stratified", fmt(st$att)),
    row_tex("",     ifelse(is.na(st$se), "", sprintf("(%s)", fmt(st$se)))),
    "\\addlinespace",
    row_tex("Observations", rep(formatC(N_OBS, big.mark = ","), 4)))
}

end_tex <- c(
  "\\\\ \\midrule",
  "  Basic SDID (QC $>$ 0 only)&  \\checkmark&  \\checkmark&            &            \\\\",
  "  Triple SDID (Difference)&            &            &  \\checkmark&  \\checkmark\\\\",
  "  Time-varying Covariates&            &  \\checkmark&            &  \\checkmark\\\\")

out_dirs <- c(file.path("results", "tables"), file.path("results", "paper"))
for (i in seq_along(OUTCOMES)) {
  tex <- panel_tex(OUTCOMES[i])
  for (d in out_dirs)
    writeLines(tex, file.path(d, sprintf("tab_sdid_county_%d.tex", i)))
  message("tab_sdid_county_", i, " (", OUTCOMES[i], "): ",
          length(tex), " lines")
}
for (d in out_dirs) writeLines(end_tex, file.path(d, "tab_sdid_county_end.tex"))

# Raw-ATT RI p-values quoted in the paper's table note — print for cross-check.
message("\nRaw-ATT RI p-values (note text), cols (1)-(4):")
for (out in OUTCOMES) {
  pr <- plac |> filter(outcome == out) |> arrange(match(spec, SPECS)) |>
    pull(p_ri_raw)
  message("  ", out, ": ", paste(sprintf("%.2f", pr), collapse = "/"))
}
message("TABLE 2 EXPORT COMPLETE")
