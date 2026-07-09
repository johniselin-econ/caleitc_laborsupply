# =============================================================================
# File:    08b_dose_table.R
# Purpose: Build the dose-response exhibit (tab:dose, PLAN.md par A.2) from the
#          committed stage-18 result set (08_dose_response.R, job 17255329).
#          Single panel, headline spec 2 (demographic controls), outcomes
#          across columns (employed / full-time / part-time), mirroring the
#          within-CA layout of tab_mw_bite. Rows: middle tercile (T2 vs T1),
#          top tercile (T3 vs T1), and the T3 - T2 gradient. Cells:
#          coef / (CRVE SE) / [state-placebo RI p]; no stars (the RI p is the
#          inference object, following tab:sdid / tab:mw_bite). The gradient is
#          a linear combination (no SE) so it shows coef / [RI p] only.
#
# Inputs:  results/dose_response/dose_post_job17255329.csv (beta_g, spec 2),
#          results/dose_response/dose_ri_job17255329.csv   (RI p, spec 2).
# Output:  results/tables/tab_dose_1.tex, mirrored to results/paper/.
#
# Usage:   Rscript code/R/08b_dose_table.R
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))
suppressPackageStartupMessages(library(dplyr))

post <- read.csv(file.path("results", "dose_response",
                           "dose_post_job17255329.csv")) |>
  filter(spec == 2)
ri <- read.csv(file.path("results", "dose_response",
                         "dose_ri_job17255329.csv"))

OUTS <- c("employed_y", "full_time_y", "part_time_y")  # column order

fmt  <- function(x) sub("^-0\\.00$", "0.00", sprintf("%.2f", x))
sfmt <- function(x) sprintf("(%s)", fmt(x))
pfmt <- function(x) sprintf("[%.2f]", x)           # RI p (coarse, k/28)

row_tex <- function(label, cells) {
  paste0(sprintf("%-30s", label),
         paste0("&", sprintf("%16s", cells), collapse = ""), "\\\\")
}

# Pull one (post term, RI term) across the three outcomes, in column order.
pull <- function(post_term, ri_term) {
  p <- post |> filter(term == post_term)
  p <- p[match(OUTS, p$outcome), ]
  r <- ri |> filter(term == ri_term)
  r <- r[match(OUTS, r$outcome), ]
  stopifnot(!anyNA(p$b), !anyNA(r$p_ri))
  list(b = p$b, se = p$se, p_ri = r$p_ri)
}

t2  <- pull("g2", "g2")
t3  <- pull("g3", "g3")
grd <- pull("g3_minus_g2", "grad")
stopifnot(all(is.na(grd$se)))  # gradient is a linear combination, no SE
N <- post$n[1]

tex <- c(
  "\\\\ \\midrule",
  "\\addlinespace",
  row_tex("Middle tercile (T2)", fmt(t2$b)),
  row_tex("", sfmt(t2$se)),
  row_tex("", pfmt(t2$p_ri)),
  "\\addlinespace",
  row_tex("Top tercile (T3)", fmt(t3$b)),
  row_tex("", sfmt(t3$se)),
  row_tex("", pfmt(t3$p_ri)),
  "\\addlinespace",
  row_tex("Gradient (T3 $-$ T2)", fmt(grd$b)),
  row_tex("", pfmt(grd$p_ri)),
  "\\addlinespace",
  row_tex("Observations", rep(formatC(N, big.mark = ","), 3)))

for (d in c("results/tables", "results/paper"))
  writeLines(tex, file.path(d, "tab_dose_1.tex"))
message("tab_dose_1: ", length(tex), " lines (N = ", N, ")")

# Event-study pre-trend flag quoted in the paper note — print for cross-check.
es <- read.csv(file.path("results", "dose_response",
                         "dose_es_job17255329.csv"))
message("\n2012 (pre) T3 coefficients, spec 2 (note text), employed/FT/PT:")
for (y in OUTS) {
  d <- es |> filter(outcome == y, term == "g3_2012")
  message("  ", y, ": ", sprintf("%.2f (SE %.2f, p %.3f)", d$b, d$se, d$p))
}
message("DOSE TABLE EXPORT COMPLETE")
