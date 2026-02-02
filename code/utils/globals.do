/*******************************************************************************
File Name:      utils/globals.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Define standard global macros for CalEITC analysis
                Centralizes variable definitions to reduce repetition across files

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** =============================================================================
** Standard Variable Lists
** =============================================================================

** Primary outcome variables
global outcomes "employed_y full_time_y part_time_y"

** Demographic control variables
global controls "education age_bracket minage_qc race_group hispanic hh_adult_ct"

** State-level economic controls
global unemp "state_unemp"
global minwage "mean_st_mw"

** Clustering variable
global clustervar "state_fips"

** =============================================================================
** Fixed Effects Specifications
** =============================================================================

** Base triple-difference fixed effects
global did_base "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"

** Event study fixed effects (same structure, different use)
global did_event "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"

** =============================================================================
** Sample Restrictions (as conditions)
** =============================================================================

** Baseline sample: Single women aged 20-49 without college degree
global baseline_sample "female == 1 & married == 0 & in_school == 0 & age_sample_20_49 == 1 & citizen_test == 1 & education < 4 & state_status > 0"

** Variables needed for baseline sample
global baseline_vars "female married in_school age_sample_20_49 citizen_test state_fips state_status"

** =============================================================================
** Standard Statistics for Tables
** =============================================================================

** Statistics list for main tables
global stats_list "N r2_a ymean C"
global stats_fmt "%9.0fc %9.3fc %9.1fc %9.0fc"

** Statistics labels (built as compound quotes for esttab)
** Note: These are assembled dynamically in export_results program

** =============================================================================
** Display confirmation
** =============================================================================

di _n "CalEITC global macros loaded:"
di "  - outcomes: $outcomes"
di "  - controls: $controls"
di "  - did_base: $did_base"
di "  - baseline_sample defined"
