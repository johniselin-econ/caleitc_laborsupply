# =============================================================================
# File:    14_sdid_fig.R
# Purpose: Event-study figures for the weighted SDID headline fits, from the
#          stage-15 output (12_sdid_eventstudy.R, job 17232065). One figure
#          per outcome x spec (12), styled to match the paper's Stata
#          coefplot event studies (plotplainblind: plain white, black point
#          estimates, capped 95% CI whiskers, dashed gray zero line, solid
#          gray divider between the 2014 base year and 2015 treatment,
#          y-title "Average Treatment Effect (pp)"). Single series — no
#          legend; grid recessive (none, per scheme).
#
#          These supersede the old fig_sdid_event_*_{basic,triple}.jpg
#          (Stata sdid_event, per-county-loop estimator, not in the paper);
#          the old files are replaced and the two new cov specs added.
#
# Inputs:  results/sdid_r/sdid_county_es_r_job17232065.csv (staged stage-15
#          curves), results/sdid_r/sdid_county_r_job17203764.csv (stage-13
#          ATTs, cross-checked against the curves' stored ATT).
# Output:  results/figures/fig_sdid_event_<outcome>_<spec>.png (local) and
#          results/paper/fig_sdid_event_<outcome>_<spec>.jpg (Overleaf
#          mirror), 2400x1600 px per export_graph convention.
#
# Usage:   Rscript code/14_sdid_fig.R
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

es <- read.csv(latest_result("sdid_r", "sdid_county_es_r"))
county <- read.csv(latest_result("sdid_r", "sdid_county_r"))

# Cross-check: each curve's stored ATT must equal the stage-13 weighted ATT
chk <- es |>
  distinct(outcome, spec, att) |>
  left_join(county |> filter(variant == "weighted") |>
              select(outcome, spec, att13 = att),
            by = c("outcome", "spec"))
stopifnot(nrow(chk) == 12, max(abs(chk$att - chk$att13)) < 1e-8)
message("ATT cross-check vs stage 13: OK (12 cells)")

TREAT_DIVIDER <- 2014.5   # after the 2014 base year, before 2015 treatment

es_plot <- function(d) {
  ymax <- max(abs(c(d$ci_lower, d$ci_upper)), na.rm = TRUE)
  ymax <- ceiling(ymax)
  ggplot(d, aes(x = year, y = estimate)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray55",
               linewidth = 0.4) +
    geom_vline(xintercept = TREAT_DIVIDER, color = "gray40",
               linewidth = 0.5) +
    geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper),
                  width = 0.18, linewidth = 0.4, color = "black") +
    geom_point(size = 1.6, color = "black") +
    scale_x_continuous(breaks = sort(unique(d$year))) +
    scale_y_continuous(limits = c(-ymax, ymax)) +
    labs(x = NULL, y = "Average Treatment Effect (pp)") +
    theme_classic(base_size = 12) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
          axis.text.y = element_text(size = 9),
          axis.title.y = element_text(size = 11))
}

cells <- es |> distinct(outcome, spec)
for (i in seq_len(nrow(cells))) {
  d <- es |> filter(outcome == cells$outcome[i], spec == cells$spec[i])
  stopifnot(nrow(d) == 8)
  p <- es_plot(d)
  base <- sprintf("fig_sdid_event_%s_%s", cells$outcome[i], cells$spec[i])
  ggsave(file.path("results", "figures", paste0(base, ".png")), p,
         width = 8, height = 16 / 3, dpi = 300)
  ggsave(file.path("results", "paper", paste0(base, ".jpg")), p,
         width = 8, height = 16 / 3, dpi = 300)
  message(base)
}
message("SDID EVENT-STUDY FIGURES COMPLETE (", nrow(cells), " cells)")
