# =============================================================================
# File:    clean_steps.R
# Purpose: R port of 01_clean_data.do Steps 1-8 (per-year ACS cleaning,
#          everything except TAXSIM). One function per Stata step; each is a
#          faithful transcription — quirks preserved on purpose:
#            * unit_ct is computed BEFORE dropping missing-pernum rows;
#            * household/tax-unit income totals are computed AFTER the
#              under-18 drop (they sum over adults only);
#            * full_time_y = employed & !part_time_y, so employed people with
#              MISSING hours count as full-time;
#            * age_bracket is NA outside ages 20-55 (egen cut semantics),
#              with 50-55 collapsed to the 50 bracket;
#            * age_grps is 0 (not NA) outside 20-50;
#            * Stata total() semantics: sums treat NA as 0 (all-NA sums to 0);
#            * county-unemployment imputation: ACS rows with unidentified or
#              unmatched county get the state-year MEAN OVER COUNTIES THAT
#              APPEAR IN THE BLS FILE BUT NOT IN THE ACS (using-only rows in
#              the Stata merge), not the mean over matched counties.
#
#          Validated row-for-row against data/final/acs_<y>_clean.dta for
#          2012 and 2015 (code/validate/validate_clean_year.R).
#
# Project: CalEITC Labor Supply Effects
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# Stata `gen` defaults to FLOAT (32-bit) storage: per-person real income
# variables are float-rounded at creation, BEFORE egen total() sums them.
# Round-trip through a 4-byte representation to reproduce that exactly —
# without this, household totals with large offsetting member values (e.g.
# incse = incearn - incwage cancellation) differ from Stata at ~1e-2.
float_round <- function(x) {
  out <- readBin(writeBin(as.numeric(x), raw(), size = 4L),
                 what = "numeric", size = 4L, n = length(x))
  out[is.na(x)] <- NA_real_
  out
}

# -----------------------------------------------------------------------------
# Aux data (01_clean_data.do:25-47): unemployment + minimum wage lookups
# -----------------------------------------------------------------------------

load_aux_data <- function() {
  st_unemp <- read_csv(path_data("interim", "bls_state_unemployment_annual.csv"),
                       show_col_types = FALSE) |>
    transmute(year, state_fips = as.integer(state_fips), state_unemp = value)

  ct_unemp <- read_csv(path_data("interim", "bls_county_unemployment_annual.csv"),
                       show_col_types = FALSE) |>
    transmute(year,
              state_fips  = suppressWarnings(as.integer(state_fips)),
              county_fips = suppressWarnings(as.integer(county_fips)),
              county_unemp = value) |>
    filter(!is.na(state_fips), !is.na(county_fips))

  st_minwage <- read_csv(path_data("interim", "VKZ_state_minwage_annual.csv"),
                         show_col_types = FALSE) |>
    transmute(year = as.integer(year),
              state_fips = suppressWarnings(as.integer(state_fips)),
              mean_st_mw = state_minwage) |>
    filter(!is.na(state_fips))

  list(st_unemp = st_unemp, ct_unemp = ct_unemp, st_minwage = st_minwage)
}

# -----------------------------------------------------------------------------
# Step 1: pre-QC prep (01_clean_data.do:92-141)
# -----------------------------------------------------------------------------

step1_prep <- function(df) {
  df <- df |>
    mutate(
      hh_id = dense_rank(serial),          # group(year serial); single year
      child = as.integer(age <= 17),
      adult = as.integer(age >= 18),
      elder = as.integer(age >= 65),
      unit_id = ifelse(marst == 1 & sploc != 0 & pernum > sploc, sploc, pernum)
    ) |>
    add_count(hh_id, unit_id, name = "unit_ct") |>   # before the pernum filter
    mutate(
      age_test     = as.integer((age < 19) | (age < 24 & school == 2)),
      citizen_test = as.integer(citizen != 3),
      joint_test   = as.integer(!(marst %in% c(1, 2, 3))),
      qc           = as.integer(age_test == 1 & citizen_test == 1 & joint_test == 1),
      hoh          = as.integer(related == 101),
      sibling      = as.integer(related == 701),
      foster       = as.integer(related == 1242),
      grandchild   = as.integer(related == 901)
    ) |>
    filter(!is.na(pernum))
  df
}

# -----------------------------------------------------------------------------
# Step 3: household composition (01_clean_data.do:147-238)
# (Step 2 is qc_assignment, ported in qc_assignment.R)
# -----------------------------------------------------------------------------

step3_household <- function(df) {
  df <- df |>
    mutate(
      qc_ct       = pmin(qc_ct, 3L),
      kid_ct      = pmin(nchild, 3L),
      qc_present  = as.integer(qc_ct > 0),
      kid_present = as.integer(nchild > 0),
      parent_ct   = (momloc != 0) + (poploc != 0) + (momloc2 != 0) + (poploc2 != 0),
      minage_qc_compr = case_when(
        is.na(min_qc_age)              ~ 0L,
        between(min_qc_age, 1, 5)      ~ 1L,
        between(min_qc_age, 6, 12)     ~ 2L,
        between(min_qc_age, 13, 23)    ~ 3L,
        .default = 0L
      ),
      minage_qc = case_when(
        is.na(min_qc_age)              ~ 0L,
        between(min_qc_age, 0, 1)      ~ 1L,
        between(min_qc_age, 2, 3)      ~ 2L,
        between(min_qc_age, 4, 6)      ~ 3L,
        between(min_qc_age, 7, 9)      ~ 4L,
        between(min_qc_age, 10, 13)    ~ 5L,
        between(min_qc_age, 14, 17)    ~ 6L,
        between(min_qc_age, 18, 24)    ~ 7L,
        .default = 0L
      ),
      minage_kid = case_when(
        kid_present == 0               ~ 0L,
        between(yngch, 0, 1)           ~ 1L,
        between(yngch, 2, 3)           ~ 2L,
        between(yngch, 4, 6)           ~ 3L,
        between(yngch, 7, 9)           ~ 4L,
        between(yngch, 10, 13)         ~ 5L,
        between(yngch, 14, 17)         ~ 6L,
        between(yngch, 18, 24)         ~ 7L,
        .default = 0L
      )
    ) |>
    select(-momloc, -momloc2, -poploc, -poploc2, -yngch, -nchild) |>
    group_by(hh_id) |>
    mutate(
      hh_person_ct = n(),
      hh_child_ct  = sum(age < 18),
      hh_qc_ct     = sum(qc),
      hh_adult_ct  = sum(age >= 18 & qc == 0)
    ) |>
    ungroup() |>
    mutate(
      hh_child_present = as.integer(hh_child_ct > 0),
      hh_qc_present    = as.integer(hh_qc_ct > 0)
    ) |>
    filter(age >= 18)                    # SAMPLE RESTRICTION (after hh counts)
  df
}

# -----------------------------------------------------------------------------
# Step 4: demographics (01_clean_data.do:240-322)
# -----------------------------------------------------------------------------

step4_demographics <- function(df) {
  df |>
    mutate(
      age_sample_20_50 = as.integer(between(age, 20, 50)),
      age_sample_20_49 = as.integer(between(age, 20, 49)),
      age_sample_25_54 = as.integer(between(age, 25, 54)),
      education = case_when(
        educd <= 61            ~ 1L,
        between(educd, 62, 64) ~ 2L,
        between(educd, 65, 80) ~ 3L,
        educd > 80             ~ 4L
      ),
      in_school = as.integer(school == 2),
      age_bracket = case_when(
        age >= 20 & age < 50   ~ 20L + 5L * ((age - 20L) %/% 5L),
        age >= 50 & age <= 55  ~ 50L,
        .default = NA_integer_
      ),
      age_grps = case_when(
        between(age, 20, 29) ~ 1L,
        between(age, 30, 39) ~ 2L,
        between(age, 40, 50) ~ 3L,
        .default = 0L
      ),
      married  = as.integer(marst %in% c(1, 2)),
      mfs      = as.integer(marst == 3 & sploc == 0),
      hispanic = as.integer(hispan != 0),
      race_group = case_when(
        race == 1           ~ 1L,
        race == 2           ~ 2L,
        race %in% c(4, 5, 6) ~ 3L,
        .default = 4L
      ),
      race_hisp = case_when(
        hispan != 0             ~ 1L,
        hispan == 0 & race == 1 ~ 2L,
        hispan == 0 & race == 2 ~ 3L,
        .default = 4L
      ),
      female = as.integer(sex == 2)
    ) |>
    select(-hispan, -race, -sex, -educ, -educd, -relate, -related,
           -school, -marst)
}

# -----------------------------------------------------------------------------
# Step 5: employment (01_clean_data.do:324-396)
# -----------------------------------------------------------------------------

step5_employment <- function(df) {
  df |>
    mutate(
      employed_y            = as.integer(workedyr == 3),
      employed_y_reported   = as.integer(qworkedy == 0),
      employed_w            = as.integer(empstat == 1),
      employed_w_reported   = as.integer(qempstat == 0),
      labor_force_w         = as.integer(empstat %in% c(1, 2)),
      hours_worked_y        = ifelse(employed_y == 1 & !is.na(uhrswork) &
                                       uhrswork > 0 & uhrswork < 99,
                                     uhrswork, NA_real_),
      hours_worked_y_reported = as.integer(quhrswor == 0),
      weeks_worked_y = case_when(
        wkswork2 == 1 ~ 7,
        wkswork2 == 2 ~ 20,
        wkswork2 == 3 ~ 33,
        wkswork2 == 4 ~ 44,
        wkswork2 == 5 ~ 48.5,
        wkswork2 == 6 ~ 51,
        .default = 0
      ),
      weeks_worked_y_reported = as.integer(qwkswork2 == 0),
      part_time_y    = as.integer(employed_y == 1 & !is.na(hours_worked_y) &
                                    hours_worked_y < 35),
      full_time_y    = as.integer(employed_y == 1 & part_time_y == 0),
      part_time_y_31 = as.integer(employed_y == 1 & !is.na(hours_worked_y) &
                                    hours_worked_y < 31),
      full_time_y_31 = as.integer(employed_y == 1 & part_time_y_31 == 0),
      part_time_y_39 = as.integer(employed_y == 1 & !is.na(hours_worked_y) &
                                    hours_worked_y < 39),
      full_time_y_39 = as.integer(employed_y == 1 & part_time_y_39 == 0),
      self_employed_w = as.integer(classwkr == 1),
      se_income_y = ifelse(!is.na(incbus00) & incbus00 != 999999, incbus00, 0),
      self_employed_y     = as.integer(se_income_y != 0),
      self_employed_pos_y = as.integer(se_income_y > 0),
      armed_services = as.integer(empstatd %in% c(14, 15))
    ) |>
    select(-workedyr, -empstat, -classwkr, -uhrswork, -labforce,
           -quhrswor, -qwkswork2, -qempstat, -qworkedy)
}

# -----------------------------------------------------------------------------
# Step 6: earnings (01_clean_data.do:398-464)
# -----------------------------------------------------------------------------

step6_earnings <- function(df, cpi99_2019 = 0.652) {
  df <- df |>
    # Stata's import delimited stored cpi99 as FLOAT (e.g. 2012 holds
    # float(0.726) = 0.7260000110), and every real-income product uses that
    # value. Mirror it or household totals with member-level cancellation
    # (incse = incearn - incwage) drift by ~1e-2 from the golden files.
    mutate(cpi99 = float_round(cpi99)) |>
    mutate(
      inctot_real       = inctot * cpi99 / cpi99_2019,
      inctot_nom        = inctot,
      incearn_real      = incearn * cpi99 / cpi99_2019,
      incearn_nom       = incearn,
      incearn_reported  = as.integer(qincwage == 0 & qincbus == 0),
      incwage_real      = incwage * cpi99 / cpi99_2019,
      incwage_nom       = incwage,
      incwage_reported  = as.integer(qincwage == 0),
      incse_nom         = incearn - incwage,
      incse_real        = (incearn - incwage) * cpi99 / cpi99_2019,
      incse_reported    = as.integer(qincwage == 0 & qincbus == 0),
      incinvst_nom      = incinvst,
      incinvst_real     = incinvst * cpi99 / cpi99_2019,
      incinvst_reported = as.integer(qincinvs == 0),
      incwel_real = ifelse(!is.na(incwelfr) & incwelfr != 999999,
                           incwelfr * cpi99 / cpi99_2019, 0),
      incwel_nom  = ifelse(!is.na(incwelfr) & incwelfr != 999999, incwelfr, 0)
    ) |>
    # mirror Stata float storage before the totals (see float_round above)
    mutate(across(c(inctot_real, incearn_real, incwage_real, incse_real,
                    incinvst_real, incwel_real),
                  float_round))

  # Household / tax-unit totals (Stata total(): NA treated as 0)
  df <- df |>
    group_by(hh_id) |>
    mutate(across(c(inctot_real, inctot_nom, incwage_real, incwage_nom,
                    incearn_real, incearn_nom, incse_real, incse_nom,
                    incinvst_real, incinvst_nom),
                  ~ sum(.x, na.rm = TRUE),
                  .names = "{sub('_(real|nom)$', '_hh_\\\\1', .col)}")) |>
    ungroup() |>
    group_by(hh_id, unit_id) |>
    mutate(across(c(inctot_real, inctot_nom, incwage_real, incwage_nom,
                    incearn_real, incearn_nom, incse_real, incse_nom,
                    incinvst_real, incinvst_nom),
                  ~ sum(.x, na.rm = TRUE),
                  .names = "{sub('_(real|nom)$', '_tax_\\\\1', .col)}")) |>
    ungroup()

  df |> select(-inctot, -incearn, -incwage, -incwelfr, -incbus00, -incinvst,
               -incsupp, -incother, -qincwage, -qincbus, -qincwelf)
}

# -----------------------------------------------------------------------------
# Step 7: unemployment / minimum wage merges (01_clean_data.do:466-508)
# -----------------------------------------------------------------------------

step7_merges <- function(df, aux) {
  df <- df |>
    mutate(state_fips = statefip, county_fips = countyfip) |>
    left_join(aux$st_unemp,   by = c("state_fips", "year")) |>
    left_join(aux$st_minwage, by = c("state_fips", "year"))

  # County unemployment: match, then impute unmatched/unidentified counties
  # with the state-year mean over BLS counties ABSENT from the ACS (the
  # using-only rows of the Stata merge)
  ct_y <- aux$ct_unemp |> filter(year %in% unique(df$year))

  df <- df |> left_join(ct_y, by = c("state_fips", "county_fips", "year"))

  unmatched_means <- ct_y |>
    anti_join(df |> distinct(state_fips, county_fips, year),
              by = c("state_fips", "county_fips", "year")) |>
    group_by(state_fips, year) |>
    summarise(ui_mean = mean(county_unemp), .groups = "drop")

  df <- df |>
    left_join(unmatched_means, by = c("state_fips", "year")) |>
    mutate(county_unemp = ifelse(county_fips == 0 | is.na(county_unemp),
                                 ui_mean, county_unemp)) |>
    select(-ui_mean, -statefip, -countyfip)

  df
}

# -----------------------------------------------------------------------------
# Step 8: state treatment assignment (01_clean_data.do:510-536)
# -----------------------------------------------------------------------------

step8_treatment <- function(df, states = params$states) {
  df |>
    mutate(state_status = case_when(
      state_fips %in% states$excluded    ~ -1L,
      state_fips == states$treated       ~ 2L,
      state_fips %in% states$eitc_change ~ 0L,
      .default = 1L
    )) |>
    filter(qc == 0)                      # SAMPLE RESTRICTION: drop QC persons
}

# -----------------------------------------------------------------------------
# Driver: Steps 1-8 for one ACS year (TAXSIM Step 9 not yet ported)
# -----------------------------------------------------------------------------

clean_acs_year <- function(y, aux, cpi99_2019 = 0.652) {
  message("Cleaning ACS year ", y)
  df <- read_csv(path_data("acs", paste0("acs_", y, ".csv")),
                 show_col_types = FALSE)
  df |>
    step1_prep() |>
    qc_assignment() |>
    step3_household() |>
    step4_demographics() |>
    step5_employment() |>
    step6_earnings(cpi99_2019 = cpi99_2019) |>
    step7_merges(aux) |>
    step8_treatment()
}
