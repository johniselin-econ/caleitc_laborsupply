/*******************************************************************************
File Name:      03_fig_event_emp.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Figure 5
                Event-study estimates of the effect of the CalEITC
                on annual employment.

                Uses utility programs: run_event_study, make_event_plot

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_event_emp
log using "${logs}03_fig_event_emp_log_${date}", name(log_03_fig_event_emp) replace text

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
use weight `outcomes' `controls' `unemp' `minwage' qc_* year ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", clear

** Create event-study interaction variable
** This creates year-specific treatment indicators for CA + QC
gen ca = (state_fips == 6)
gen childXyearXca = cond(qc_present == 1 & ca == 1, year, 2014)

** Update adults per HH (cap at 3)
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

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

** Create coefficient plot using utility program
make_event_plot est_employed_y est_full_time_y est_part_time_y, ///
    eventvar(childXyearXca) ///
    startyear(`start') ///
    endyear(`end') ///
    baseyear(2014) ///
    ymax(6) ///
    ycut(2) ///
    savepath("${results}figures/fig_event_emp.jpg") ///
    labels(Employed|Employed full-time|Employed part-time)

** Also save as PNG
graph export "${results}figures/fig_event_emp.png", ///
    as(png) name("Graph") width(2400) height(1600) replace

** Save to Overleaf if enabled
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_event_emp.jpg", as(jpg) quality(100) replace
}

** =============================================================================
** Export coefficients for reference
** =============================================================================

** Create dataset of coefficients
preserve
    clear
    gen outcome = ""
    gen year = .
    gen coef = .
    gen se = .
    gen ci_lo = .
    gen ci_hi = .

    local row = 1
    foreach out in employed_y full_time_y part_time_y {
        forvalues y = `start'(1)`end' {
            if `y' != 2014 {
                qui est restore est_`out'
                local b = _b[`y'.childXyearXca]
                local s = _se[`y'.childXyearXca]

                set obs `row'
                qui replace outcome = "`out'" in `row'
                qui replace year = `y' in `row'
                qui replace coef = `b' in `row'
                qui replace se = `s' in `row'
                qui replace ci_lo = `b' - 1.96 * `s' in `row'
                qui replace ci_hi = `b' + 1.96 * `s' in `row'

                local row = `row' + 1
            }
        }
    }

    export delimited "${results}tables/fig_event_emp_coefficients.csv", replace
restore

** =============================================================================
** End
** =============================================================================

log close log_03_fig_event_emp
