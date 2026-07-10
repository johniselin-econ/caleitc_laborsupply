# =============================================================================
# Diagnostic figures for the FTB 3514 CalEITC parameter audit (PLAN.md Phase 2).
#
# One figure per tax year (2015-2019): credit vs earned income, one line per
# qualifying-children count. Each panel overlays
#   - solid line:  verified piecewise schedule from config/caleitc_ftb3514.yaml
#   - dots:        FTB's published $50-bin credit table (ground truth),
#                  data/eitc_parameters/ftb3514/caleitc_table_{year}.csv,
#                  plotted at bin midpoints
#   - dashed line: the superseded eitc_california block in
#                  config/parameters.yaml, built with the exact formula from
#                  02_eitc_param_prep.do:217-225 (phase-in to kink1, phase-out
#                  from kink1, credit = 0 above max_income). Old block covers
#                  TY2015-17 and QC 1-3 only (childless coded ineligible).
#
# The audit "looks right" if the solid lines sit on the dots and the dashed
# lines visibly do not.
#
# Run from the repo root: Rscript code/validate/fig_caleitc_ftb3514_audit.R
# Output: results/diagnostics/caleitc_ftb3514/fig_caleitc_schedule_ty{year}.png
# =============================================================================

library(ggplot2)
library(yaml)

root <- getwd()
new_params <- read_yaml(file.path(root, "config/caleitc_ftb3514.yaml"))$eitc_california_ftb3514
old_params <- read_yaml(file.path(root, "config/parameters.yaml"))$eitc_california
out_dir <- file.path(root, "results/diagnostics/caleitc_ftb3514")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Verified schedule: phase-in to kink1, then the piecewise phase-out segments,
# hard zero above max_income (the credit cliff).
credit_ftb3514 <- function(p, x) {
  cred <- rep(0, length(x))
  cred[x <= p$kink1] <- p$phasein_rate * x[x <= p$kink1]
  seg_x <- p$kink1
  seg_c <- p$max_credit
  for (seg in p$phaseout) {
    end_x <- if (!is.null(seg$zero_at)) seg$zero_at else seg$to
    idx <- x > seg_x & x <= end_x
    cred[idx] <- seg_c - seg$rate * (x[idx] - seg_x)
    seg_c <- seg_c - seg$rate * (end_x - seg_x)
    seg_x <- end_x
  }
  cred[x > p$max_income] <- 0
  pmax(cred, 0)
}

# Old repo schedule, exactly as 02_eitc_param_prep.do computes it:
# earnings*rate below kink1; max(0, max_credit - rate*(earn - kink1)) between
# kink1 and max_income; 0 above max_income.
credit_old <- function(p, x) {
  cred <- ifelse(x <= p$kink1,
                 p$phasein_rate * x,
                 pmax(0, p$max_credit - p$phaseout_rate * (x - p$kink1)))
  cred[x > p$max_income] <- 0
  cred
}

# Palette (validated categorical slots 1-4; sub-3:1 slots get direct labels)
qc_levels <- paste(0:3, "QC")
qc_cols <- c("0 QC" = "#2a78d6", "1 QC" = "#1baf7a",
             "2 QC" = "#eda100", "3 QC" = "#008300")
ink <- "#0b0b0b"; ink2 <- "#52514e"; muted <- "#898781"
grid_col <- "#e1e0d9"; surface <- "#fcfcfb"

for (year in names(new_params)) {
  np <- new_params[[year]]
  op <- old_params[[year]]  # NULL for 2018-2019

  x_max <- max(sapply(np, `[[`, "max_income")) + 1500
  grid_x <- seq(0, x_max, by = 10)

  lines <- do.call(rbind, lapply(0:3, function(q) {
    key <- paste0("qc", q)
    out <- data.frame(income = grid_x, qc = paste(q, "QC"),
                      credit = credit_ftb3514(np[[key]], grid_x),
                      source = "Verified FTB 3514")
    if (!is.null(op[[key]])) {
      out <- rbind(out, data.frame(income = grid_x, qc = paste(q, "QC"),
                                   credit = credit_old(op[[key]], grid_x),
                                   source = "Repo params (old)"))
    }
    out
  }))
  lines$qc <- factor(lines$qc, levels = qc_levels)
  lines$source <- factor(lines$source,
                         levels = c("Verified FTB 3514", "Repo params (old)"))

  tab <- read.csv(file.path(root, sprintf(
    "data/eitc_parameters/ftb3514/caleitc_table_%s.csv", year)))
  # Numeric check on the FULL table (independent reimplementation of the
  # piecewise schedule vs FTB's published bins; audit claims <= $6, <= $19
  # for TY2018 where FTB's table has a duplicated row):
  dev <- sapply(0:3, function(q) {
    mid <- (tab$earn_low + tab$earn_high) / 2
    max(abs(credit_ftb3514(np[[paste0("qc", q)]], mid) -
            tab[[paste0("credit_qc", q)]]))
  })
  message(sprintf("TY%s max |piecewise - table|: %s",
                  year, paste0("qc", 0:3, "=$", round(dev, 1), collapse = " ")))
  tab <- tab[seq(1, nrow(tab), by = 4), ]  # every 4th $50 bin, for legibility
  dots <- do.call(rbind, lapply(0:3, function(q) {
    data.frame(income = (tab$earn_low + tab$earn_high) / 2,
               qc = paste(q, "QC"),
               credit = tab[[paste0("credit_qc", q)]])
  }))
  dots$qc <- factor(dots$qc, levels = qc_levels)

  peaks <- do.call(rbind, lapply(0:3, function(q) {
    p <- np[[paste0("qc", q)]]
    data.frame(income = p$kink1, credit = p$max_credit, qc = paste(q, "QC"))
  }))
  peaks$qc <- factor(peaks$qc, levels = qc_levels)

  subtitle <- if (is.null(op)) {
    "Solid: verified schedule · dots: FTB credit table (no repo params this year)"
  } else {
    "Solid: verified schedule · dots: FTB credit table · dashed: old repo params (QC 1-3)"
  }

  gg <- ggplot(lines, aes(income, credit, color = qc)) +
    geom_line(aes(linetype = source), linewidth = 0.7) +
    geom_point(data = dots, aes(shape = "FTB credit table (every 4th $50 bin)"),
               size = 1.4, alpha = 0.85, stroke = 0.45, fill = NA) +
    geom_text(data = peaks, aes(label = qc), vjust = -0.7, hjust = 0.4,
              size = 3.1, fontface = "bold", show.legend = FALSE) +
    scale_color_manual(values = qc_cols, guide = "none") +
    scale_linetype_manual(name = NULL,
                          values = c("Verified FTB 3514" = "solid",
                                     "Repo params (old)" = "42")) +
    scale_shape_manual(name = NULL,
                       values = c("FTB credit table (every 4th $50 bin)" = 1)) +
    scale_x_continuous(labels = scales::dollar_format(),
                       expand = expansion(mult = c(0.01, 0.03))) +
    scale_y_continuous(labels = scales::dollar_format(),
                       expand = expansion(mult = c(0, 0.10))) +
    guides(linetype = guide_legend(order = 1,
                                   override.aes = list(color = ink2)),
           shape = guide_legend(order = 2,
                                override.aes = list(color = ink2, size = 2,
                                                    alpha = 1))) +
    labs(title = sprintf("CalEITC schedule, TY%s", year),
         subtitle = subtitle,
         x = "Earned income", y = "CalEITC credit") +
    theme_minimal(base_size = 11) +
    theme(plot.background = element_rect(fill = surface, color = NA),
          panel.grid.minor = element_blank(),
          panel.grid.major = element_line(color = grid_col, linewidth = 0.3),
          plot.title = element_text(color = ink, face = "bold"),
          plot.subtitle = element_text(color = ink2, size = 8.5),
          axis.title = element_text(color = ink2, size = 9),
          axis.text = element_text(color = muted),
          legend.position = "top",
          legend.justification = "left",
          legend.margin = margin(0, 0, -4, 0),
          legend.text = element_text(color = ink2, size = 8.5))

  out_file <- file.path(out_dir, sprintf("fig_caleitc_schedule_ty%s.png", year))
  ggsave(out_file, gg, width = 7.5, height = 4.8, dpi = 150, bg = surface)
  message("wrote ", out_file)
}
