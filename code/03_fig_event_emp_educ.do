/*******************************************************************************
File Name:      03_fig_event_emp_educ.do
Creator:        John Iselin
Date Update:    July 2026

Purpose:        Produces fig_event_emp_educ.{png,jpg} and
                fig_event_emp_educ_coefficients.csv: event-study version of
                the within-California education triple-difference
                (companion to 03_tab_main_educ.do), fully saturated spec
                with county FEs and demographic controls.

                RECOVERED July 2026 from the original run log
                (03_fig_event_emp_educ_log_2026-03-05.log): the do-file was
                lost from the repo, but the log echoes the full script. This
                file is a faithful transcription.

                VALIDATION TARGETS (from the 2026-03-05 log, CA N=132,910;
                matches committed fig_event_emp_educ_coefficients.csv):
                  employed 2016 = 2.887 (1.124), 2017 = 4.099 (1.179)
                  full-time 2017 = 3.311 (1.890)
                  part-time 2015 = 2.357 (2.305)

                Uses utility programs: run_event_study, make_event_plot,
                export_event_coefficients, export_graph

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_event_emp_educ
log using "${logs}03_fig_event_emp_educ_log_${date}", ///
    name(log_03_fig_event_emp_educ) replace text

** =============================================================================
** Load data — CA only, all education levels
** =============================================================================

local outcomes "employed_y full_time_y part_time_y"
local controls "age_bracket minage_qc race_group hispanic hh_adult_ct"

use weight `outcomes' `controls' state_unemp mean_st_mw qc_* year ///
    female married in_school age_sample_20_49 citizen_test ///
    state_fips county_fips education ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        state_fips == 6 & ///
        inrange(year, ${start_year}, ${end_year}) ///
    using "${data}final/acs_working_file.dta", clear

di _n "Loaded CA-only sample (all education levels): N = " _N

** =============================================================================
** Create DID variables
** =============================================================================

** No-college indicator
gen nocollege = (education < 4)

** Event-study interaction: QC x Year x No-College
gen childXyearXnocol = cond(qc_present == 1 & nocollege == 1, year, 2014)

** Cap adults per HH at 3
replace hh_adult_ct = 3 if hh_adult_ct > 3
capture label drop lb_adult_ct
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** Triple-diff FEs: education replaces state, county added
local did_event "qc_ct year education qc_ct#year qc_ct#education year#education county_fips"

** =============================================================================
** Run event-study regressions (fully saturated spec with county FEs + controls)
** =============================================================================

foreach out of local outcomes {

    ** Scale outcome to percentage points
    replace `out' = `out' * 100

    ** Run event-study regression
    eststo est_`out': ///
        run_event_study `out', ///
            eventvar(childXyearXnocol) ///
            baseyear(2014) ///
            controls(`controls') ///
            fes(`did_event') ///
            weightvar(weight) ///
            clustervar(county_fips)

}

** =============================================================================
** Create coefficient plot
** =============================================================================

make_event_plot est_employed_y est_full_time_y est_part_time_y, ///
    eventvar(childXyearXnocol) ///
    startyear(${start_year}) ///
    endyear(${end_year}) ///
    baseyear(2014) ///
    ymax(6) ///
    ycut(2) ///
    savepath("${results}figures/fig_event_emp_educ.jpg") ///
    labels(Employed|Employed full-time|Employed part-time)

** Export graph using utility
export_graph, filename("fig_event_emp_educ")

** =============================================================================
** Export coefficients for reference
** =============================================================================

export_event_coefficients est_employed_y est_full_time_y est_part_time_y, ///
    eventvar(childXyearXnocol) ///
    startyear(${start_year}) ///
    endyear(${end_year}) ///
    baseyear(2014) ///
    outfile("${results}tables/fig_event_emp_educ_coefficients.csv")

** =============================================================================
** End
** =============================================================================

log close log_03_fig_event_emp_educ
