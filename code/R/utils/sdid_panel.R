# =============================================================================
# File:    sdid_panel.R
# Purpose: Build the SDID county panel from the R working file — port of the
#          panel-build section of 03_sdid_county.do (lines 78-222; replicated
#          for the golden file by code/hpc/stage10_sdid_panel.do).
#
#          Faithfulness notes (Stata semantics preserved):
#          - Balance rule: a (state, county, QC-group) cell keeps its county
#            code only if it is observed in ALL panel years; otherwise
#            county_fips is recoded to 0 and the collapse pools it with the
#            state's other unbalanced counties. The rule is per QC group, so
#            a county can be balanced for one QC group and pooled for the
#            other.
#          - collapse (mean) [fw=weight] drops missing outcome values cell by
#            cell (weighted.mean(..., na.rm = TRUE)); pop = sum(weight) over
#            ALL rows in the cell regardless of outcome missingness.
#          - pop/`diff`/covariate arithmetic keeps R's NA propagation, which
#            matches Stata missing arithmetic here (a cell missing one QC
#            group yields missing pop, diff, and pooled covariates).
#          - fips = egen group(state_fips county_fips): dense rank over the
#            sorted (state, county) pairs.
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

SDID_OUTCOMES <- c("employed_y", "full_time_y", "part_time_y", "incearn_real")
SDID_CONTROLS <- c("unemp", "minwage")

build_sdid_county_panel <- function(wf, start_year = 2010, end_year = 2017) {
  num_years <- end_year - start_year + 1

  long <- wf |>
    filter(female == 1, married == 0, in_school == 0, age_sample_20_49 == 1,
           citizen_test == 1, education < 4, state_status > 0,
           year >= start_year, year <= end_year) |>
    mutate(unemp = coalesce(county_unemp, state_unemp),
           minwage = mean_st_mw,
           employed_y = 100 * employed_y,
           full_time_y = 100 * full_time_y,
           part_time_y = 100 * part_time_y) |>
    select(year, state_fips, county_fips, all_of(SDID_OUTCOMES),
           all_of(SDID_CONTROLS), weight, qc_present)

  # Unbalanced counties -> county_fips 0 (per state x county x QC group)
  long <- long |>
    group_by(state_fips, county_fips, qc_present) |>
    mutate(balanced = n_distinct(year) == num_years) |>
    ungroup() |>
    mutate(county_fips = replace(county_fips, !balanced, 0)) |>
    select(-balanced)

  # Collapse to county x year x QC cells
  wmean <- function(x, w) {
    m <- weighted.mean(x, w, na.rm = TRUE)
    if (is.nan(m)) NA_real_ else m
  }
  cells <- long |>
    group_by(state_fips, county_fips, qc_present, year) |>
    summarise(across(all_of(c(SDID_OUTCOMES, SDID_CONTROLS)),
                     ~ wmean(.x, weight)),
              pop = sum(weight), .groups = "drop")

  # Reshape wide by QC group; Stata names: <var>0 / <var>1
  wide <- cells |>
    pivot_wider(id_cols = c(state_fips, county_fips, year),
                names_from = qc_present,
                values_from = all_of(c(SDID_OUTCOMES, SDID_CONTROLS, "pop")),
                names_glue = "{.value}{qc_present}")

  wide <- wide |>
    mutate(pop = pop0 + pop1,
           unemp = (unemp0 * pop0 + unemp1 * pop1) / pop,
           minwage = (minwage0 * pop0 + minwage1 * pop1) / pop)

  for (out in SDID_OUTCOMES) {
    wide[[paste0(out, "_diff")]] <- wide[[paste0(out, "1")]] - wide[[paste0(out, "0")]]
    names(wide)[names(wide) == paste0(out, "1")] <- out
    names(wide)[names(wide) == paste0(out, "0")] <- paste0(out, "_qc0")
  }

  wide |>
    mutate(treated = as.integer(state_fips == 6 & year >= 2015),
           constant = 1) |>
    arrange(state_fips, county_fips, year) |>
    group_by(state_fips, county_fips) |>
    mutate(fips = cur_group_id()) |>
    ungroup() |>
    relocate(state_fips, county_fips, fips, year, treated)
}
