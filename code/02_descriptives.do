/*******************************************************************************
File Name:      02_descriptives.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Generate descriptive statistics for CalEITC analysis

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_02_desc
log using "${logs}02_log_descriptives_${date}", name(log_02_desc) replace text

** =============================================================================
** Load data and define sample
** =============================================================================

** Load cleaned ACS data
use "${data}final/acs_working_file.dta", clear

** Define analysis sample: single women aged 20-49 without college degree
keep if female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, ${start_year}, ${end_year})

** Create treatment indicators
gen ca = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)

** =============================================================================
** Summary statistics by treatment status
** =============================================================================

** Variables for summary statistics
local summ_vars "employed_y full_time_y part_time_y hours_worked_y weeks_worked_y"
local summ_vars "`summ_vars' age education qc_ct hh_adult_ct"
local summ_vars "`summ_vars' incearn_real incwage_real"

** Pre-period summary statistics
eststo clear

** California, with QC (treated group)
eststo ca_qc: estpost summarize `summ_vars' [aw=weight] ///
    if ca == 1 & qc_present == 1 & post == 0

** California, without QC
eststo ca_noqc: estpost summarize `summ_vars' [aw=weight] ///
    if ca == 1 & qc_present == 0 & post == 0

** Control states, with QC
eststo ctrl_qc: estpost summarize `summ_vars' [aw=weight] ///
    if ca == 0 & qc_present == 1 & post == 0

** Control states, without QC
eststo ctrl_noqc: estpost summarize `summ_vars' [aw=weight] ///
    if ca == 0 & qc_present == 0 & post == 0

** Export summary statistics table
esttab ca_qc ca_noqc ctrl_qc ctrl_noqc using ///
    "${results}tables/descriptives_preperiod.tex", ///
    cells("mean(fmt(2)) sd(fmt(2))") ///
    label nostar noobs nonumber nomtitle ///
    collabels("Mean" "SD") ///
    title("Pre-Period Summary Statistics") ///
    replace

** =============================================================================
** Sample sizes by year and treatment group
** =============================================================================

** Count observations
tab year ca if qc_present == 1 [aw=weight], matcell(ct_qc)
tab year ca if qc_present == 0 [aw=weight], matcell(ct_noqc)

** =============================================================================
** Employment trends by group
** =============================================================================

** Collapse to year-group means
preserve
    collapse (mean) employed_y full_time_y part_time_y ///
             (rawsum) n = weight ///
             [aw=weight], ///
             by(year ca qc_present)

    ** Export for plotting
    export delimited "${results}tables/employment_trends.csv", replace
restore

** =============================================================================
** End
** =============================================================================

log close log_02_desc
