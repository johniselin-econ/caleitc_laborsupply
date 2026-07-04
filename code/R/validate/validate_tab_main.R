# =============================================================================
# File:    validate_tab_main.R
# Purpose: Coefficient-by-coefficient validation of the run_triple_diff port
#          against the committed main table (golden values below are the
#          exact reghdfe output from the cluster stage-1 run,
#          code/logs/phase0_stage1_2026-07-02.log, which produced the
#          committed tab_main_{1,2,3}.tex on the canonical rebuilt extract,
#          N = 461,616).
#
#          Asserts: coefficient relative error < 1e-6, clustered-SE relative
#          error < 1e-4 (reghdfe dof convention via SSC_REGHDFE), N exact.
#
# Usage:   Rscript code/R/validate/validate_tab_main.R   (needs ~15 GB RAM;
#          run via sbatch on the cluster)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "R", "utils", "config.R"))
source(file.path("code", "R", "utils", "estimation.R"))

suppressPackageStartupMessages(library(haven))

# Golden values: reghdfe treated coef / cluster-robust SE, per outcome x spec
GOLDEN <- tibble::tribble(
  ~outcome,      ~spec, ~b,         ~se,
  "employed_y",  1,      0.8280433, 0.3733102,
  "employed_y",  2,      0.3512457, 0.3585408,
  "employed_y",  3,      0.3128080, 0.4638773,
  "employed_y",  4,     -0.3347120, 0.5710567,
  "full_time_y", 1,     -2.2231450, 0.4512137,
  "full_time_y", 2,     -2.5371450, 0.4503198,
  "full_time_y", 3,     -2.8308820, 0.6970392,
  "full_time_y", 4,     -4.0766440, 0.7952907,
  "part_time_y", 1,      3.0511890, 0.3737982,
  "part_time_y", 2,      2.8883910, 0.3891284,
  "part_time_y", 3,      3.1436900, 0.6443122,
  "part_time_y", 4,      3.7419320, 0.6724554
)
GOLDEN_N <- 461616L

message("Loading working file (column-selected) ...")

df <- read_dta(
  path_data("final", "acs_working_file.dta"),
  col_select = c(weight, employed_y, full_time_y, part_time_y,
                 education, age_bracket, minage_qc, race_group, hispanic,
                 hh_adult_ct, state_unemp, mean_st_mw, year,
                 female, married, in_school, age_sample_20_49, citizen_test,
                 state_fips, state_status, qc_ct, qc_present)
) |> zap_labels()

# Baseline sample (globals.do: $baseline_sample) + analysis years
df <- df |>
  filter(female == 1, married == 0, in_school == 0, age_sample_20_49 == 1,
         citizen_test == 1, education < 4, state_status > 0,
         year >= params$years$analysis_start,
         year <= params$years$analysis_end)

message("Baseline sample: N = ", nrow(df),
        " (expect ", format(GOLDEN_N, big.mark = ","), ")")
stopifnot(nrow(df) == GOLDEN_N)

# DID variables + outcome scaling (03_tab_main.do)
df <- setup_did_vars(df) |>
  mutate(across(c(employed_y, full_time_y, part_time_y), ~ .x * 100))

# Run the 12 specifications
run_spec <- function(outcome, spec) {
  switch(spec,
    run_triple_diff(outcome, df),
    run_triple_diff(outcome, df, controls = CONTROLS),
    run_triple_diff(outcome, df, controls = CONTROLS,
                    unempvar = "state_unemp", qcvar = "qc_ct"),
    run_triple_diff(outcome, df, controls = CONTROLS,
                    unempvar = "state_unemp", minwagevar = "mean_st_mw",
                    qcvar = "qc_ct")
  )
}

results <- GOLDEN |>
  rowwise() |>
  mutate(
    est    = list(run_spec(outcome, spec)),
    b_r    = coef(est)[["treated"]],
    se_r   = sqrt(vcov(est)[["treated", "treated"]]),
    n_r    = nobs(est),
    b_err  = abs(b_r / b - 1),
    se_err = abs(se_r / se - 1)
  ) |>
  ungroup() |>
  select(-est)

print(as.data.frame(results |>
  mutate(across(c(b, b_r, se, se_r), ~ round(.x, 7)))), digits = 7)

stopifnot(all(results$n_r == GOLDEN_N))
stopifnot(all(results$b_err < 1e-6))

if (all(results$se_err < 1e-4)) {
  message("===== tab_main validation PASSED (coefs < 1e-6, SEs < 1e-4) =====")
} else {
  message("Coefficients PASS; SE max relative error = ",
          format(max(results$se_err), digits = 3),
          " — inspect ssc() convention before accepting.")
  stop("SE convention mismatch")
}
