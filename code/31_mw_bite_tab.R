# =============================================================================
# File:    31_mw_bite_tab.R
# Purpose: Build the paper's minimum-wage bite-test exhibit (tab:mw_bite, the
#          "Threats to identification" subsection, PLAN.md par A.1 / par C)
#          from the stage-16 results (job 17232853; all defaults reviewed and
#          kept as implemented, author decisions 2026-07-07):
#            Panel A — within-CA county-year DiD horse race: post x MW-bite
#              and post x CalEITC-exposure (pop-weighted z-scores), entered
#              jointly and each alone; county + year FE, pop-weighted,
#              county-clustered (35 clusters). Cells: coef / (SE) /
#              [cluster-t p] for the joint model; coef / (SE) for the
#              entered-alone rows. No stars (few-cluster inference).
#            Panel B — weighted triple SDID excluding the local-ordinance
#              treated counties (drop3 = LA/SF/Santa Clara; drop4 adds
#              Alameda), with the full-sample stage-13 weighted triple fit
#              (Table 2 column 3) as the reference row. Cells: ATT / (SE).
#          Fragment layout mirrors tab_sdid_county_* (booktabs fragment,
#          prehead "\\ \midrule") so the paper's tabular shell is standard.
#
# Inputs:  results/mw_bite/mw_bite_reg_job17232853.csv (Part 2),
#          results/mw_bite/mw_bite_sdid_drop_job17232853.csv (Part 3),
#          results/sdid_r/sdid_county_r_job17203764.csv (full-sample row).
# Output:  results/tables/tab_mw_bite_{1,2}.tex, mirrored to results/paper/
#          (the Overleaf tables/ staging dir).
#
# Usage:   Rscript code/31_mw_bite_tab.R
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
suppressPackageStartupMessages(library(dplyr))

reg  <- read.csv(file.path("results", "mw_bite",
                           "mw_bite_reg_job17232853.csv"))
drop <- read.csv(file.path("results", "mw_bite",
                           "mw_bite_sdid_drop_job17232853.csv"))
full <- read.csv(file.path("results", "sdid_r",
                           "sdid_county_r_job17203764.csv")) |>
  filter(spec == "triple", variant == "weighted")

# Columns (1)-(3): the triple margins, Table 2 panel order
OUTS_REG  <- c("employed_y_diff", "full_time_y_diff", "part_time_y_diff")
OUTS_SDID <- c("employed_y", "full_time_y", "part_time_y")
N_OBS <- 280  # 35 CA units x 2010-2017 (asserted below)
stopifnot(all(reg$n == N_OBS), nrow(full) == 3)

fmt  <- function(x) sprintf("%.2f", x)
sfmt <- function(x) sprintf("(%s)", fmt(x))
pfmt <- function(x) sprintf("[%.3f]", x)

row_tex <- function(label, cells) {
  paste0(sprintf("%-34s", label),
         paste0("&", sprintf("%14s", cells), collapse = ""), "\\\\")
}

# Pull (est, se, p) across the three outcomes for one model x term.
pull_reg <- function(mod, trm) {
  d <- reg |> filter(model == mod, term == trm)
  d <- d[match(OUTS_REG, d$outcome), ]
  stopifnot(!anyNA(d$est))
  d
}

## Panel A: horse race + entered-alone rows --------------------------------------
hb <- pull_reg("horse", "post_bite")
he <- pull_reg("horse", "post_exp")
ab <- pull_reg("bite",  "post_bite")
ae <- pull_reg("exp",   "post_exp")

panelA <- c(
  "\\\\ \\midrule",
  row_tex("\\emph{Entered jointly:}", rep("", 3)),
  row_tex("Post $\\times$ MW bite", fmt(hb$est)),
  row_tex("", sfmt(hb$se)),
  row_tex("", pfmt(hb$p)),
  row_tex("Post $\\times$ CalEITC exposure", fmt(he$est)),
  row_tex("", sfmt(he$se)),
  row_tex("", pfmt(he$p)),
  "\\addlinespace",
  row_tex("\\emph{Entered alone:}", rep("", 3)),
  row_tex("Post $\\times$ MW bite", fmt(ab$est)),
  row_tex("", sfmt(ab$se)),
  row_tex("Post $\\times$ CalEITC exposure", fmt(ae$est)),
  row_tex("", sfmt(ae$se)),
  "\\addlinespace",
  row_tex("Observations", rep(formatC(N_OBS, big.mark = ","), 3)))

## Panel B: ordinance-drop SDID ---------------------------------------------------
pull_sdid <- function(d) {
  d <- d[match(OUTS_SDID, d$outcome), ]
  stopifnot(!anyNA(d$att))
  d
}
fs <- pull_sdid(full)
d3 <- pull_sdid(drop |> filter(variant == "drop3"))
d4 <- pull_sdid(drop |> filter(variant == "drop4"))
stopifnot(all(d3$N1 == 32), all(d4$N1 == 31))

panelB <- c(
  "\\\\ \\midrule",
  row_tex("Full sample", fmt(fs$att)),
  row_tex("", sfmt(fs$se)),
  row_tex("Drop LA, SF, Santa Clara", fmt(d3$att)),
  row_tex("", sfmt(d3$se)),
  row_tex("Drop LA, SF, Santa Clara, Alameda", fmt(d4$att)),
  row_tex("", sfmt(d4$se)))

out_dirs <- c(file.path("results", "tables"), file.path("results", "paper"))
for (d in out_dirs) {
  writeLines(panelA, file.path(d, "tab_mw_bite_1.tex"))
  writeLines(panelB, file.path(d, "tab_mw_bite_2.tex"))
}
message("tab_mw_bite_1: ", length(panelA), " lines; tab_mw_bite_2: ",
        length(panelB), " lines")

# Kaitz-variant horse race quoted in the table note — print for cross-check.
message("\nKaitz-variant horse race (note text), employed/FT/PT:")
for (trm in c("post_kaitz", "post_exp")) {
  k <- pull_reg("kaitz", trm)
  message("  ", trm, ": ",
          paste(sprintf("%.2f (%.2f)", k$est, k$se), collapse = " / "))
}
message("MW BITE TABLE EXPORT COMPLETE")
