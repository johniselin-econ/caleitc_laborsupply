# =============================================================================
# File:    34_earnbins_scale.R
# Purpose: PLAN.md par A.7 follow-up to stage 17 (job 17253645): the raw
#          earnings-density permutation statistic put CA 3rd of 28, behind
#          North Dakota and Utah — small-state sampling noise dominating the
#          placebo tails, the same size-vs-noise conflation the paper's SDID
#          RI resolves with RMSPE scaling (03b author decisions). This stage
#          re-runs Part 3 saving per-state Kish effective sample sizes and
#          adds the precision-scaled variant T_s * sqrt(n_eff_s) alongside
#          the raw statistic (sampling sd of T_s is proportional to
#          1/sqrt(n_eff_s) under the multinomial null, so the scaled
#          statistic is comparable across states — the RMSPE-scaling logic).
#          Raw remains the headline; scaled flagged for author review.
#          Same conventions: exhaustive over state_status == 1 placebos,
#          +1, one-sided (into the credit range) and two-sided. No seeds.
#
# Inputs:  data/final/acs_working_file_r.rds
# Output:  data/tmp/earnbins_scaled_states.csv, earnbins_scaled_p.csv
#
# Usage:   Rscript code/34_earnbins_scale.R  (cluster:
#          stage17b_earnbins_scale.sbatch; ~64G load, minutes of compute)
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
suppressPackageStartupMessages(library(dplyr))

BIN_W    <- 6000
BIN_MAX  <- 60000
CAL_BINS <- c(6000, 12000)
cpi99    <- params$prices$cpi99
TO_2017  <- cpi99[["2019"]] / cpi99[["2017"]]

message("Loading working file ...")
wf <- readRDS(path_data("final", "acs_working_file_r.rds"))
eb <- wf |>
  filter(female == 1, married == 0, in_school == 0, age_sample_20_49 == 1,
         citizen_test == 1, education < 4, state_status > 0, employed_y == 1,
         year >= params$years$analysis_start,
         year <= params$years$analysis_end) |>
  select(weight, year, state_fips, qc_present, incearn_real)
rm(wf); invisible(gc())

eb <- eb |>
  mutate(post = as.integer(year > 2014),
         earn17 = incearn_real * TO_2017,
         bin = ifelse(!is.na(earn17) & earn17 >= 0 & earn17 < BIN_MAX,
                      floor(earn17 / BIN_W) * BIN_W, NA_real_)) |>
  filter(!is.na(bin))
message("Binned employed sample: N = ", nrow(eb))

neff <- eb |>
  group_by(state_fips) |>
  summarise(n = n(), n_eff = sum(weight)^2 / sum(weight^2), .groups = "drop")

shares <- eb |>
  group_by(state_fips, post, qc_present, bin) |>
  summarise(wt = sum(weight), .groups = "drop_last") |>
  mutate(share = 100 * wt / sum(wt)) |>
  ungroup()

dbin <- shares |>
  select(-wt) |>
  tidyr::complete(state_fips, post, qc_present,
                  bin = seq(0, BIN_MAX - BIN_W, by = BIN_W),
                  fill = list(share = 0)) |>
  tidyr::pivot_wider(names_from = c(post, qc_present), values_from = share,
                     names_prefix = "s") |>
  mutate(D = (s1_1 - s0_1) - (s1_0 - s0_0))

tstats <- dbin |>
  group_by(state_fips) |>
  summarise(T = sum(D[bin %in% CAL_BINS]), .groups = "drop") |>
  left_join(neff, by = "state_fips") |>
  mutate(T_scaled = T * sqrt(n_eff),
         is_ca = as.integer(state_fips == 6))

pvals <- function(stat_col) {
  a  <- tstats[[stat_col]][tstats$is_ca == 1]
  pl <- tstats[[stat_col]][tstats$is_ca == 0]
  S  <- length(pl)
  data.frame(stat = stat_col, T_ca = a, S = S,
             rank = 1 + sum(pl > a),
             p_one = (1 + sum(pl >= a)) / (S + 1),
             p_two = (1 + sum(abs(pl) >= abs(a))) / (S + 1))
}
res <- bind_rows(pvals("T"), pvals("T_scaled"))
print(res, row.names = FALSE)

write.csv(tstats, path_data("tmp", "earnbins_scaled_states.csv"),
          row.names = FALSE)
write.csv(res, path_data("tmp", "earnbins_scaled_p.csv"), row.names = FALSE)
message("EARNBINS SCALED STAGE COMPLETE")
