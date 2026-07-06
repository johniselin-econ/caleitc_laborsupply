# =============================================================================
# Regenerate data/eitc_parameters/caleitc_params.txt — the sim-3 kink targets —
# transparently from FTB's published credit tables (PLAN.md Phase 2).
#
# Provenance (resolved 2026-07-06; the file previously had no producing script):
# each value is the MIDPOINT OF THE $50 CREDIT-TABLE BIN IN WHICH THE CalEITC
# ATTAINS ITS MAXIMUM, per tax year x QC count, from the parsed FTB Form 3514
# tables in data/eitc_parameters/ftb3514/caleitc_table_{year}.csv. Verified
# 2026-07-06: this construction reproduces the committed file byte-for-byte
# for every year and QC count — the sim-3 targets were always consistent with
# FTB 3514 (unlike the superseded eitc_california schedule parameters; see
# config/caleitc_ftb3514.yaml and the 2026-07-05 audit).
#
# Column convention (consumed by 01_clean_data.do:707 / taxsim.R sim-3 and
# 02_elasticities.do:302 / 02_mvpf.do:34):
#   - 2015+ rows populate `pwages` (nominal-dollar kink target for that year);
#     `pwages_unadj` is empty.
#   - pre-2015 rows (2010-2014, before the CalEITC existed) populate
#     `pwages_unadj` with the NOMINAL 2015 values; sim-3 reflates them by
#     cpi_2015/cpi99(year) at use. `pwages` is empty.
#
# Run from the repo root: Rscript code/R/gen_caleitc_params.R
# The output is committed; after regeneration `git diff` should be empty.
# =============================================================================

out_path <- "data/eitc_parameters/caleitc_params.txt"

kink_mid <- function(year, q) {
  tab <- read.csv(sprintf(
    "data/eitc_parameters/ftb3514/caleitc_table_%d.csv", year))
  credit <- tab[[paste0("credit_qc", q)]]
  peak <- which(credit == max(credit))
  mid <- unique((tab$earn_low[peak] + tab$earn_high[peak]) / 2)
  stopifnot(length(mid) == 1)  # the argmax bin must be unique
  mid
}

fmt <- function(x) format(x, trim = TRUE, scientific = FALSE)

lines <- "tax_year\tqc_ct\tpwages\tpwages_unadj"
for (year in 2010:2019) {
  for (q in 0:3) {
    mid <- kink_mid(max(year, 2015), q)  # pre-2015 rows carry the 2015 kink
    lines <- c(lines, if (year < 2015) {
      sprintf("%d\t%d\t\t%s", year, q, fmt(mid))
    } else {
      sprintf("%d\t%d\t%s\t", year, q, fmt(mid))
    })
  }
}

writeLines(lines, out_path)
message("wrote ", out_path, " (", length(lines) - 1, " rows)")
