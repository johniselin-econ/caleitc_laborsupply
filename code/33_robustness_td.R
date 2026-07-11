# =============================================================================
# File:    33_robustness_td.R
# Purpose: PLAN.md par A.3 / A.5 / A.7 — three working-file robustness tests
#          for the "Threats to identification" agenda, one data load:
#
#          Part 1 (A.3) — Medicaid-expansion control pool. The baseline
#          triple-diff (eq1, 4 nested specs x employed/FT/PT) re-estimated
#          restricting the control pool to Medicaid-expansion states
#          (03_fig_spec_curve.do:81-86 FIPS list; CA stays as treated).
#          CA expanded Medicaid January 2014: if the results were driven by
#          the expansion, they should attenuate against expansion-state
#          controls, and the response should date to 2014 not 2015. Also
#          re-runs the eq3 event studies (full-controls spec) on this pool
#          for the 2015-not-2014 break.
#
#          Part 2 (A.5) — alternative full-time thresholds. The 4 nested
#          specs for {full,part}_time_y_{31,39} (thresholds built in the
#          working file; baseline is 35). The 31-hour threshold also spans
#          the ACA employer-mandate 30-hour margin.
#
#          Part 3 (A.7) — earnings-density permutation test. Formalizes the
#          Fig. earn-bins evidence: per state, the bin-level density DiD
#          D_bin = (share_post,QC - share_pre,QC) - (share_post,noQC -
#          share_pre,noQC) over $6,000 bins of real earnings (2017 USD,
#          0-60k, employed women, matching 03_fig_earn_bins.do), and the
#          statistic T = sum of D_bin over the CalEITC bins [$6k, $18k).
#          T_CA is compared to the placebo distribution {T_s} over the
#          state_status == 1 control states; p = (1 + #{T_s >= T_CA}) /
#          (S + 1) (one-sided: the credit moves mass INTO the range;
#          two-sided on |T| also reported). Exhaustive over states — no
#          seeds anywhere in this stage.
#
#          Defaults flagged for author review: the CalEITC bin range
#          ([$6k,$18k) = bins 2-3 of the $6k grid, per PLAN par A.7), the
#          2017-USD denomination (matches the figure's EITC overlay), and
#          the one-sided convention for the headline p.
#
# Inputs:  data/final/acs_working_file_r.rds
# Output:  data/tmp/robustness_medicaid.csv, robustness_medicaid_es.csv,
#          robustness_altthresh.csv, robustness_earnbins_states.csv,
#          robustness_earnbins_bins.csv, + combined robustness_td.rds
#
# Usage:   Rscript code/33_robustness_td.R  (cluster:
#          stage17_robustness_td.sbatch; ~64G for the working-file load)
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
source(file.path("code", "lib", "estimation.R"))


## Constants --------------------------------------------------------------------
# Medicaid-expansion pool (03_fig_spec_curve.do:81-86; includes CA = 6)
MEDICAID_FIPS <- c(4, 5, 6, 8, 9, 10, 11, 15, 17, 19, 21, 24, 25, 26, 27,
                   32, 33, 34, 35, 36, 38, 39, 41, 44, 50, 53, 54)
BIN_W     <- 6000                      # earnings bin width, 2017 USD
BIN_MAX   <- 60000                     # bins cover [0, 60k)
CAL_BINS  <- c(6000, 12000)            # bin lower edges of the CalEITC range
cpi99   <- params$prices$cpi99
TO_2017 <- cpi99[["2019"]] / cpi99[["2017"]]   # incearn_real (2019 USD) -> 2017

## Load + baseline sample ---------------------------------------------------------
message("Loading working file ...")
wf <- readRDS(path_data("final", "acs_working_file_r.rds"))
df <- wf |>
  filter(female == 1, married == 0, in_school == 0, age_sample_20_49 == 1,
         citizen_test == 1, education < 4, state_status > 0,
         year >= params$years$analysis_start,
         year <= params$years$analysis_end) |>
  select(weight, year, state_fips, state_status, qc_ct, qc_present,
         employed_y, full_time_y, part_time_y,
         full_time_y_31, part_time_y_31, full_time_y_39, part_time_y_39,
         education, age_bracket, minage_qc, race_group, hispanic,
         hh_adult_ct, state_unemp, mean_st_mw, incearn_real)
rm(wf); invisible(gc())
message("Baseline sample: N = ", nrow(df))

df <- setup_did_vars(df, eventstudy = TRUE) |>
  mutate(across(c(employed_y, full_time_y, part_time_y,
                  full_time_y_31, part_time_y_31,
                  full_time_y_39, part_time_y_39), ~ .x * 100))

run_spec <- function(outcome, spec, data) {
  switch(spec,
    run_triple_diff(outcome, data),
    run_triple_diff(outcome, data, controls = CONTROLS),
    run_triple_diff(outcome, data, controls = CONTROLS,
                    unempvar = "state_unemp", qcvar = "qc_ct"),
    run_triple_diff(outcome, data, controls = CONTROLS,
                    unempvar = "state_unemp", minwagevar = "mean_st_mw",
                    qcvar = "qc_ct")
  )
}
tidy_fit <- function(fit, outcome, spec, G, term = "treated") {
  ct <- coeftable(fit)
  data.frame(outcome = outcome, spec = spec, b = ct[term, 1],
             se = ct[term, 2], p = ct[term, 4], n = nobs(fit), G = G)
}

## Part 1: Medicaid-expansion pool -------------------------------------------------
dmed <- df |> filter(state_fips %in% MEDICAID_FIPS)
G_med <- length(unique(dmed$state_fips))
message("Medicaid pool: N = ", nrow(dmed), ", states = ", G_med)

med <- list()
for (y in c("employed_y", "full_time_y", "part_time_y")) for (s in 1:4)
  med[[paste(y, s)]] <- tidy_fit(run_spec(y, s, dmed), y, s, G_med)
med <- bind_rows(med)
write.csv(med, path_data("tmp", "robustness_medicaid.csv"), row.names = FALSE)
message("\n=== Part 1: Medicaid pool, treated coef by outcome x spec ===")
print(med |> mutate(across(c(b, se, p), \(x) round(x, 3))), row.names = FALSE)

med_es <- list()
for (y in c("employed_y", "full_time_y", "part_time_y")) {
  fit <- run_event_study(y, dmed, controls = CONTROLS,
                         unempvar = "state_unemp", minwagevar = "mean_st_mw",
                         qcvar = "qc_ct")
  ct <- as.data.frame(coeftable(fit))
  keep <- grepl("childXyearXca", rownames(ct))
  med_es[[y]] <- data.frame(
    outcome = y,
    year = as.integer(sub(".*::", "", rownames(ct)[keep])),
    b = ct[keep, 1], se = ct[keep, 2], p = ct[keep, 4], n = nobs(fit))
}
med_es <- bind_rows(med_es)
write.csv(med_es, path_data("tmp", "robustness_medicaid_es.csv"),
          row.names = FALSE)

## Part 2: alternative full-time thresholds ----------------------------------------
G_all <- length(unique(df$state_fips))
alt <- list()
for (y in c("full_time_y_31", "part_time_y_31",
            "full_time_y_39", "part_time_y_39")) for (s in 1:4)
  alt[[paste(y, s)]] <- tidy_fit(run_spec(y, s, df), y, s, G_all)
alt <- bind_rows(alt)
write.csv(alt, path_data("tmp", "robustness_altthresh.csv"), row.names = FALSE)
message("\n=== Part 2: alt thresholds, treated coef by outcome x spec ===")
print(alt |> mutate(across(c(b, se, p), \(x) round(x, 3))), row.names = FALSE)

## Part 3: earnings-density permutation test ---------------------------------------
eb <- df |>
  filter(employed_y == 100) |>
  mutate(earn17 = incearn_real * TO_2017,
         bin = ifelse(!is.na(earn17) & earn17 >= 0 & earn17 < BIN_MAX,
                      floor(earn17 / BIN_W) * BIN_W, NA_real_)) |>
  filter(!is.na(bin))

shares <- eb |>
  group_by(state_fips, post, qc_present, bin) |>
  summarise(wt = sum(weight), .groups = "drop_last") |>
  mutate(share = 100 * wt / sum(wt)) |>
  ungroup()

# Bin-level DiD per state; T = sum over the CalEITC bins
dbin <- shares |>
  select(-wt) |>
  tidyr::complete(state_fips, post, qc_present, bin = seq(0, BIN_MAX - BIN_W,
                                                          by = BIN_W),
                  fill = list(share = 0)) |>
  tidyr::pivot_wider(names_from = c(post, qc_present), values_from = share,
                     names_prefix = "s") |>
  mutate(D = (s1_1 - s0_1) - (s1_0 - s0_0))

tstats <- dbin |>
  group_by(state_fips) |>
  summarise(T = sum(D[bin %in% CAL_BINS]), .groups = "drop") |>
  mutate(is_ca = as.integer(state_fips == 6))

t_ca <- tstats$T[tstats$is_ca == 1]
t_pl <- tstats$T[tstats$is_ca == 0]
S <- length(t_pl)
p_one <- (1 + sum(t_pl >= t_ca)) / (S + 1)
p_two <- (1 + sum(abs(t_pl) >= abs(t_ca))) / (S + 1)
message(sprintf(paste0("\n=== Part 3: T_CA = %.3f pp; placebo S = %d, ",
                       "range [%.2f, %.2f]; p_one = %.3f, p_two = %.3f ==="),
                t_ca, S, min(t_pl), max(t_pl), p_one, p_two))

write.csv(tstats, path_data("tmp", "robustness_earnbins_states.csv"),
          row.names = FALSE)
write.csv(dbin |> filter(state_fips == 6),
          path_data("tmp", "robustness_earnbins_bins.csv"), row.names = FALSE)

saveRDS(list(medicaid = med, medicaid_es = med_es, altthresh = alt,
             earnbins = list(tstats = tstats, dbin_ca = dbin |>
                               filter(state_fips == 6),
                             p_one = p_one, p_two = p_two,
                             cal_bins = CAL_BINS, bin_w = BIN_W,
                             usd = 2017)),
        path_data("tmp", "robustness_td.rds"))
message("ROBUSTNESS TD STAGE COMPLETE")
