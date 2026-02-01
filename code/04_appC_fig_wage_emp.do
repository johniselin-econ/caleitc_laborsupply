/*******************************************************************************
File Name:      04_appC_fig_wage_emp.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix C Figure 1
                Event-study estimates of the effect of the CalEITC on annual
                employment, restricted to wage-workers.

                Uses utility programs: run_event_study, make_event_plot

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appC_fig_wage_emp
log using "${logs}04_appC_fig_wage_emp_log_${date}", ///
    name(log_04_appC_fig_wage_emp) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define outcome variables
local outcomes "employed_y full_time_y part_time_y"

** Define control variables
local controls "education age_bracket minage_qc race_group hispanic hh_adult_ct"

** Define unemployment control variable
local unemp "state_unemp"

** Define minimum wage control variable
local minwage "mean_st_mw"

** Define cluster variable
local clustervar "state_fips"

** Define start and end dates
local start = ${start_year}
local end = ${end_year}

** SPECIFICATION (Fixed Effects)
local did "qc_ct year state_fips"
local did "`did' state_fips#year"
local did "`did' state_fips#qc_ct"
local did "`did' year#qc_ct"

** =============================================================================
** Load data and define sample
** =============================================================================

** Load ACS data
use weight `outcomes' `controls' `unemp' `minwage' qc_* year incwage_real ///
    female married in_school age citizen_test state_fips state_status ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        inrange(age, 20, 50) & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", clear

** Create event-study interaction variable
gen ca = (state_fips == 6)
gen childXyearXca = cond(qc_present == 1 & ca == 1, year, 2014)

** Update adults per HH (cap at 3)
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** =============================================================================
** Restrict sample to wage workers
** =============================================================================

** Update outcomes for wage earnings only
replace incwage_real = 0 if incwage_real == .
gen any_wage = (incwage_real > 0)

** Adjust outcomes to only count those with wage income
foreach out of local outcomes {
    replace `out' = (`out' == 1 & any_wage == 1)
}

** Label minimum wage variable
label var mean_st_mw "Binding state minimum wage"

** =============================================================================
** Run event-study regressions using utility program
** =============================================================================

** Loop over outcome variables
foreach out of local outcomes {

    ** Scale outcome to percentage points
    replace `out' = `out' * 100

    ** Run event-study regression using utility program
    eststo est_`out': ///
        run_event_study `out', ///
            eventvar(childXyearXca) ///
            baseyear(2014) ///
            controls(`controls') ///
            unempvar(`unemp') ///
            minwagevar(`minwage') ///
            fes(`did') ///
            weightvar(weight) ///
            clustervar(`clustervar') ///
            qcvar(qc_ct)
}

** =============================================================================
** Create coefficient plot using utility program
** =============================================================================

** Create coefficient plot
make_event_plot est_employed_y est_full_time_y est_part_time_y, ///
    eventvar(childXyearXca) ///
    startyear(`start') ///
    endyear(`end') ///
    baseyear(2014) ///
    ymax(6) ///
    ycut(2) ///
    savepath("${results}figures/fig_appC_fig1.jpg") ///
    labels(Employed|Employed full-time|Employed part-time)

** Also save as PNG
graph export "${results}figures/fig_appC_wage_emp.png", ///
    as(png) name("Graph") width(2400) height(1600) replace

** Save to Overleaf if enabled
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_appC_wage_emp.jpg", as(jpg) quality(100) replace
}

** =============================================================================
** End
** =============================================================================

log close log_04_appC_fig_wage_emp
