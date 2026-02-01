/*******************************************************************************
File Name:      03_fig_event_earn.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Figure: Event-study estimates of the effect of the
                CalEITC on annual earnings (PPML).

                Includes:
                - Own earned income (incearn_real)
                - Total household income (inctot_hh_real)
                - Other household income (incother_hh_real = inctot_hh - incearn)

                Uses utility programs: run_ppml_event_study

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_event_earn
log using "${logs}03_fig_event_earn_log_${date}", name(log_03_fig_event_earn) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define outcome variables (incother_hh_real created below)
local outcomes "incearn_real inctot_hh_real incother_hh_real"

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
use weight incearn_real inctot_hh_real `controls' `unemp' `minwage' qc_* year ///
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

** Handle missing income values
replace incearn_real = 0 if incearn_real == .
replace inctot_hh_real = 0 if inctot_hh_real == .

** Create other household income (HH income minus own earnings)
gen incother_hh_real = inctot_hh_real - incearn_real
replace incother_hh_real = 0 if incother_hh_real < 0

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
** Run event-study regressions for all outcomes
** =============================================================================

foreach out of local outcomes {

    ** Define sample (PPML allows zeros)
    gen sample = `out' >= 0 & !missing(`out')

    ** Run PPML event-study regression
    eststo est_`out': ///
        run_ppml_event_study `out', ///
            eventvar(childXyearXca) ///
            baseyear(2014) ///
            controls(`controls') ///
            unempvar(`unemp') ///
            minwagevar(`minwage') ///
            fes(`did') ///
            weightvar(weight) ///
            clustervar(`clustervar') ///
            qcvar(qc_ct) ///
            samplecond(sample == 1)

    drop sample

}

** =============================================================================
** Create individual coefficient plots
** =============================================================================

** Generate coefficient labels
local coef `""'
local keep ""

forvalues y = `start'(1)`end' {
    local keep "`keep' `y'.childXyearXca"
    local coef `"`coef' `y'.childXyearXca = "`y'""'
}

** Set up xlines (line should appear AFTER base year, before treatment)
local xline_val = 2014 - `start' + 1.5

** Plot for own earnings
coefplot est_incearn_real, ///
    keep(`keep') ///
    coeflabels(`coef') ///
    msize(medsmall) ///
    ytitle("PPML Coefficient, Own Earnings") ///
    xlabel(, angle(45)) ///
    xline(`xline_val', lcolor(red)) ///
    omitted baselevels ///
    yline(0, lcolor(black) lpattern(dash)) ///
    vertical ciopts(recast(rcap)) ///
    legend(off)

** Save figure
graph export "${results}figures/fig_event_earn_own.jpg", as(jpg) name("Graph") quality(100) replace

if ${overleaf} == 1 {
    graph export "${ol_fig}fig_event_earn_own.jpg", as(jpg) quality(100) replace
}

** Plot for household income
coefplot est_inctot_hh_real, ///
    keep(`keep') ///
    coeflabels(`coef') ///
    msize(medsmall) ///
    ytitle("PPML Coefficient, Household Income") ///
    xlabel(, angle(45)) ///
    xline(`xline_val', lcolor(red)) ///
    omitted baselevels ///
    yline(0, lcolor(black) lpattern(dash)) ///
    vertical ciopts(recast(rcap)) ///
    legend(off)

** Save figure
graph export "${results}figures/fig_event_inc_hh.jpg", as(jpg) name("Graph") quality(100) replace

if ${overleaf} == 1 {
    graph export "${ol_fig}fig_event_inc_hh.jpg", as(jpg) quality(100) replace
}

** Plot for other household income (HH income minus own earnings)
coefplot est_incother_hh_real, ///
    keep(`keep') ///
    coeflabels(`coef') ///
    msize(medsmall) ///
    ytitle("PPML Coefficient, Other HH Income") ///
    xlabel(, angle(45)) ///
    xline(`xline_val', lcolor(red)) ///
    omitted baselevels ///
    yline(0, lcolor(black) lpattern(dash)) ///
    vertical ciopts(recast(rcap)) ///
    legend(off)

** Save figure
graph export "${results}figures/fig_event_inc_other.jpg", as(jpg) name("Graph") quality(100) replace

if ${overleaf} == 1 {
    graph export "${ol_fig}fig_event_inc_other.jpg", as(jpg) quality(100) replace
}

** =============================================================================
** Create combined coefficient plot with all three outcomes
** =============================================================================

** Build coefficient dataset for combined plot
preserve
    clear
    local numyears = `end' - `start' + 1
    local numobs = `numyears' * 3
    set obs `numobs'

    gen outcome = ""
    gen year = .
    gen coef = .
    gen se = .
    gen ci_lo = .
    gen ci_hi = .

    local row = 1
    foreach out in incearn_real inctot_hh_real incother_hh_real {
        qui est restore est_`out'
        forvalues y = `start'(1)`end' {
            if `y' != 2014 {
                local b = _b[`y'.childXyearXca]
                local s = _se[`y'.childXyearXca]
            }
            else {
                local b = 0
                local s = 0
            }

            qui replace outcome = "`out'" in `row'
            qui replace year = `y' in `row'
            qui replace coef = `b' in `row'
            qui replace se = `s' in `row'
            qui replace ci_lo = `b' - 1.96 * `s' in `row'
            qui replace ci_hi = `b' + 1.96 * `s' in `row'

            local row = `row' + 1
        }
    }

    ** Create x positions with offset for each outcome
    gen xpos = year - `start' + 1
    replace xpos = xpos - 0.15 if outcome == "incearn_real"
    replace xpos = xpos + 0.15 if outcome == "incother_hh_real"
    ** inctot_hh_real stays at center (no offset)

    ** Calculate xline position (after 2014, before 2015)
    local xline_pos = 2014 - `start' + 1.5

    ** Plot combined figure
    twoway ///
        (rcap ci_lo ci_hi xpos if outcome == "incearn_real", lcolor(navy)) ///
        (scatter coef xpos if outcome == "incearn_real", mcolor(navy) msymbol(O)) ///
        (rcap ci_lo ci_hi xpos if outcome == "inctot_hh_real", lcolor(cranberry)) ///
        (scatter coef xpos if outcome == "inctot_hh_real", mcolor(cranberry) msymbol(D)) ///
        (rcap ci_lo ci_hi xpos if outcome == "incother_hh_real", lcolor(forest_green)) ///
        (scatter coef xpos if outcome == "incother_hh_real", mcolor(forest_green) msymbol(T)) ///
        , ///
        yline(0, lcolor(black) lpattern(dash)) ///
        xline(`xline_pos', lcolor(red)) ///
        ytitle("PPML Coefficient") ///
        xtitle("") ///
        xlabel(1 "2012" 2 "2013" 3 "2014" 4 "2015" 5 "2016" 6 "2017", nogrid) ///
        ylabel(-.3(.1).3, angle(0)) ///
        legend(order(2 "Own Earnings" 4 "Total HH Income" 6 "Other HH Income") ///
               rows(1) position(6) region(lcolor(white))) ///
        graphregion(color(white)) ///
        plotregion(margin(b=0))

    ** Save combined figure
    graph export "${results}figures/fig_event_earn.jpg", as(jpg) name("Graph") quality(100) replace

    ** Also save as PNG
    graph export "${results}figures/fig_event_earn.png", ///
        as(png) name("Graph") width(2400) height(1600) replace

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        graph export "${ol_fig}fig_event_earn.jpg", as(jpg) quality(100) replace
    }

    ** -------------------------------------------------------------------------
    ** Version without Other HH Income (just Own Earnings and Total HH Income)
    ** -------------------------------------------------------------------------

    ** Adjust x positions for two-series plot
    drop xpos
    gen xpos = year - `start' + 1
    replace xpos = xpos - 0.1 if outcome == "incearn_real"
    replace xpos = xpos + 0.1 if outcome == "inctot_hh_real"

    ** Plot combined figure (two outcomes only)
    twoway ///
        (rcap ci_lo ci_hi xpos if outcome == "incearn_real", lcolor(navy)) ///
        (scatter coef xpos if outcome == "incearn_real", mcolor(navy) msymbol(O)) ///
        (rcap ci_lo ci_hi xpos if outcome == "inctot_hh_real", lcolor(cranberry)) ///
        (scatter coef xpos if outcome == "inctot_hh_real", mcolor(cranberry) msymbol(D)) ///
        , ///
        yline(0, lcolor(black) lpattern(dash)) ///
        xline(`xline_pos', lcolor(red)) ///
        ytitle("PPML Coefficient") ///
        xtitle("") ///
        xlabel(1 "2012" 2 "2013" 3 "2014" 4 "2015" 5 "2016" 6 "2017", nogrid) ///
        ylabel(-.3(.1).3, angle(0)) ///
        legend(order(2 "Own Earnings" 4 "Total HH Income") ///
               rows(1) position(6) region(lcolor(white))) ///
        graphregion(color(white)) ///
        plotregion(margin(b=0))

    ** Save figure
    graph export "${results}figures/fig_event_earn_2.jpg", as(jpg) name("Graph") quality(100) replace

    ** Also save as PNG
    graph export "${results}figures/fig_event_earn_2.png", ///
        as(png) name("Graph") width(2400) height(1600) replace

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        graph export "${ol_fig}fig_event_earn_2.jpg", as(jpg) quality(100) replace
    }

    ** Export coefficients for reference
    export delimited "${results}tables/fig_event_earn_coefficients.csv", replace

restore

** =============================================================================
** End
** =============================================================================

clear
log close log_03_fig_event_earn
