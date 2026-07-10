# =============================================================================
# File:    validate_event_study.R
# Purpose: Validate the run_event_study port against the committed
#          results/tables/fig_event_emp_coefficients.csv (produced by
#          03_fig_event_emp.do on the canonical rebuilt extract — verified
#          against the 2026-03-06 run log; employed 2012 = .912229).
#
#          Spec: full spec-4 analog — demographic controls + unemployment x QC
#          + minimum wage x QC, did_event FEs, state-clustered.
#          Asserts coef relative error < 1e-6 and SE relative error < 1e-4
#          for all 3 outcomes x 5 event years.
#
# Usage:   Rscript code/validate/validate_event_study.R  (sbatch; ~15 GB)
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
source(file.path("code", "lib", "estimation.R"))

suppressPackageStartupMessages({
  library(haven)
  library(readr)
})

golden <- read_csv(path_results("tables", "fig_event_emp_coefficients.csv"),
                   show_col_types = FALSE)

df <- read_dta(
  path_data("final", "acs_working_file.dta"),
  col_select = c(weight, employed_y, full_time_y, part_time_y,
                 education, age_bracket, minage_qc, race_group, hispanic,
                 hh_adult_ct, state_unemp, mean_st_mw, year,
                 female, married, in_school, age_sample_20_49, citizen_test,
                 state_fips, state_status, qc_ct, qc_present)
) |> zap_labels()

df <- df |>
  filter(female == 1, married == 0, in_school == 0, age_sample_20_49 == 1,
         citizen_test == 1, education < 4, state_status > 0,
         year >= params$years$analysis_start,
         year <= params$years$analysis_end)

df <- setup_did_vars(df, eventstudy = TRUE) |>
  mutate(across(c(employed_y, full_time_y, part_time_y), ~ .x * 100))

results <- list()
for (out in c("employed_y", "full_time_y", "part_time_y")) {
  est <- run_event_study(out, df,
                         controls = CONTROLS,
                         unempvar = "state_unemp",
                         minwagevar = "mean_st_mw",
                         qcvar = "qc_ct")
  cf <- coef(est); se <- sqrt(diag(vcov(est)))
  keep <- grepl("childXyearXca", names(cf))
  results[[out]] <- tibble::tibble(
    outcome = out,
    year    = as.integer(sub(".*::", "", names(cf)[keep])),
    coef_r  = unname(cf[keep]),
    se_r    = unname(se[keep])
  )
}

cmp <- golden |>
  inner_join(dplyr::bind_rows(results), by = c("outcome", "year")) |>
  mutate(b_err = abs(coef_r / coef - 1), se_err = abs(se_r / se - 1))

stopifnot(nrow(cmp) == nrow(golden))

print(as.data.frame(cmp |> select(outcome, year, coef, coef_r, se, se_r,
                                  b_err, se_err)), digits = 7)

stopifnot(all(cmp$b_err < 1e-6), all(cmp$se_err < 1e-4))
message("===== event-study validation PASSED (", nrow(cmp), " coefficients) =====")
