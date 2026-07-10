# =============================================================================
# File:    11b_mvpf_figures.R
# Purpose: MVPF exhibits (Phase 4b) from the committed 11_mvpf.R model grid:
#            fig_mvpf_distribution  — histogram of mvpf_4 across all specs, with
#              vertical lines at the six preferred (design x CF) specifications
#              (paper Fig, \Cref{fig:fig_hist_2017_f1_mvpf}); ports
#              03_fig_mvpf_dist.do.
#            fig_mvpf_spillovers    — fiscal externality by revenue source for
#              the preferred spec across the three FT-PT counterfactual incomes
#              (paper \Cref{fig:appA_fiscal_spill}); ports 03_fig_mvpf_spillovers.do
#              (opt3 "observed effect" components, real 2017 $M).
#          Matches the repo's theme_classic paper-figure style (cf. 03e).
#
# Inputs:  results/mvpf/mvpf_models_job17750705.csv
# Output:  results/figures/fig_mvpf_{distribution,spillovers}.{png,jpg} +
#          results/paper/ mirrors (Overleaf staging).
#
# Usage:   Rscript code/R/11b_mvpf_figures.R
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))
suppressPackageStartupMessages({library(dplyr); library(tidyr); library(ggplot2)})

m <- read.csv(file.path("results", "mvpf", "mvpf_models_job17750705.csv"))

save_fig <- function(p, base, w = 8, h = 16/3) {
  ggsave(file.path("results", "figures", paste0(base, ".png")), p,
         width = w, height = h, dpi = 300)
  for (d in c("results/figures", "results/paper"))
    ggsave(file.path(d, paste0(base, ".jpg")), p, width = w, height = h,
           dpi = 300, quality = 100)
  message(base, " written")
}

## Figure 1: MVPF distribution -------------------------------------------------
# Preferred cells: sample=1, spec_d=1, contrs=0, hetero=2; design 0 (spec_u/m=1)
# vs design 1 (spec_u/m=0), across the three counterfactual incomes.
pref <- m |>
  filter(sample == 1, spec_d == 1, contrs == 0, hetero == 2,
         (design == 0 & spec_u == 1 & spec_m == 1) |
         (design == 1 & spec_u == 0 & spec_m == 0)) |>
  mutate(cf = factor(ft_pt_cf, 1:3, c("Min wage", "Median", "Mean")),
         des = factor(design, 0:1, c("Triple-diff", "Quad-diff")),
         lab = paste0(des, ", ", cf, " CF"))
CFCOL <- c("Min wage" = "#3b6", "Median" = "#38c", "Mean" = "#c63")

p1 <- ggplot(m, aes(x = mvpf_4)) +
  geom_histogram(aes(y = after_stat(count / sum(count) * 100)),
                 bins = 20, fill = "gray70", color = "white", linewidth = 0.2) +
  geom_vline(data = pref, aes(xintercept = mvpf_4, color = cf, linetype = des),
             linewidth = 0.6, show.legend = TRUE) +
  scale_color_manual(values = CFCOL, name = "Counterfactual FT income") +
  scale_linetype_manual(values = c("Triple-diff" = "solid",
                                   "Quad-diff" = "dashed"), name = "Design") +
  scale_x_continuous(breaks = seq(0.4, 0.95, 0.05)) +
  labs(x = "Marginal Value of Public Funds (MVPF)",
       y = "Percent of estimates (%)") +
  theme_classic(base_size = 12) +
  theme(legend.position = "bottom", legend.box = "vertical",
        legend.key.width = unit(1.4, "lines"))
save_fig(p1, "fig_mvpf_distribution")

## Figure 2: fiscal spillovers by revenue source -------------------------------
sp <- m |>
  filter(sample == 1, spec_d == 1, spec_u == 1, spec_m == 1, contrs == 0,
         hetero == 2, design == 0) |>
  transmute(cf = factor(ft_pt_cf, 1:3, c("Min wage", "Median", "Mean")),
            `Federal IIT` = eff_fed_liab,
            `Federal payroll tax` = eff_pay_liab,
            `State IIT (less CalEITC)` = eff_st_nocal_liab,
            `Federal EITC` = -eff_fedeitc,          # credits: expenditure sign
            `Federal CTC` = -eff_ctc) |>
  pivot_longer(-cf, names_to = "source", values_to = "eff") |>
  mutate(source = factor(source, c("Federal IIT", "Federal payroll tax",
            "State IIT (less CalEITC)", "Federal EITC", "Federal CTC")))

p2 <- ggplot(sp, aes(x = source, y = eff, fill = cf)) +
  geom_col(position = position_dodge(0.8), width = 0.75) +
  geom_hline(yintercept = 0, linewidth = 0.3, color = "gray40") +
  scale_fill_manual(values = c("Min wage" = "gray75", "Median" = "gray50",
                               "Mean" = "gray25"), name = "Counterfactual FT income") +
  labs(x = NULL, y = "Change in government revenue (Mil, 2017 USD)") +
  theme_classic(base_size = 12) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1, size = 9),
        legend.position = "bottom")
save_fig(p2, "fig_mvpf_spillovers")
message("MVPF FIGURES COMPLETE")
