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

                Uses utility programs: load_baseline_sample, setup_did_vars,
                run_ppml_event_study, export_graph

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

** =============================================================================
** Load data and setup
** =============================================================================

** Load baseline sample with income variables
load_baseline_sample, varlist(incearn_real inctot_hh_real)

** Handle missing income values
replace incearn_real = 0 if incearn_real == .
replace inctot_hh_real = 0 if inctot_hh_real == .

** Create other household income (HH income minus own earnings)
gen incother_hh_real = inctot_hh_real - incearn_real
replace incother_hh_real = 0 if incother_hh_real < 0

** Create DID variables (including event study variable)
setup_did_vars, eventstudy

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
            controls($controls) ///
            unempvar($unemp) ///
            minwagevar($minwage) ///
            fes($did_event) ///
            weightvar(weight) ///
            clustervar($clustervar) ///
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

forvalues y = ${start_year}(1)${end_year} {
    local keep "`keep' `y'.childXyearXca"
    local coef `"`coef' `y'.childXyearXca = "`y'""'
}

** Set up xlines (line should appear AFTER base year, before treatment)
local xline_val = 2014 - ${start_year} + 1.5

** Plot for own earnings (scheme-consistent)
coefplot est_incearn_real, ///
    keep(`keep') ///
    coeflabels(`coef') ///
    msize(small) pstyle(p1) ///
    ytitle("PPML Coefficient, Own Earnings") ///
    xlabel(, angle(45) labsize(small)) ///
    ylabel(, labsize(small)) ///
    xline(`xline_val', lcolor(gs6)) ///
    omitted baselevels ///
    yline(0, lcolor(gs8) lpattern(dash)) ///
    vertical ciopts(recast(rcap)) ///
    legend(off)

** Export graph
export_graph, filename("fig_event_earn_own")

** Plot for household income (scheme-consistent)
coefplot est_inctot_hh_real, ///
    keep(`keep') ///
    coeflabels(`coef') ///
    msize(small) pstyle(p1) ///
    ytitle("PPML Coefficient, Household Income") ///
    xlabel(, angle(45) labsize(small)) ///
    ylabel(, labsize(small)) ///
    xline(`xline_val', lcolor(gs6)) ///
    omitted baselevels ///
    yline(0, lcolor(gs8) lpattern(dash)) ///
    vertical ciopts(recast(rcap)) ///
    legend(off)

** Export graph
export_graph, filename("fig_event_inc_hh")

** Plot for other household income (scheme-consistent)
coefplot est_incother_hh_real, ///
    keep(`keep') ///
    coeflabels(`coef') ///
    msize(small) pstyle(p1) ///
    ytitle("PPML Coefficient, Other HH Income") ///
    xlabel(, angle(45) labsize(small)) ///
    ylabel(, labsize(small)) ///
    xline(`xline_val', lcolor(gs6)) ///
    omitted baselevels ///
    yline(0, lcolor(gs8) lpattern(dash)) ///
    vertical ciopts(recast(rcap)) ///
    legend(off)

** Export graph
export_graph, filename("fig_event_inc_other")

** =============================================================================
** Create combined coefficient plot with all three outcomes
** =============================================================================

** Build coefficient dataset for combined plot
preserve
    clear
    local numyears = ${end_year} - ${start_year} + 1
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
        forvalues y = ${start_year}(1)${end_year} {
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
    gen xpos = year - ${start_year} + 1
    replace xpos = xpos - 0.15 if outcome == "incearn_real"
    replace xpos = xpos + 0.15 if outcome == "incother_hh_real"
    ** inctot_hh_real stays at center (no offset)

    ** Calculate xline position (after 2014, before 2015)
    local xline_pos = 2014 - ${start_year} + 1.5

    ** Build xlabel from globals
    local xlabs ""
    forvalues y = ${start_year}(1)${end_year} {
        local pos = `y' - ${start_year} + 1
        local xlabs `"`xlabs' `pos' "`y'""'
    }

    ** Plot combined figure (scheme-consistent)
    twoway ///
        (rcap ci_lo ci_hi xpos if outcome == "incearn_real", lcolor(stc1)) ///
        (scatter coef xpos if outcome == "incearn_real", mcolor(stc1) msymbol(O) msize(small)) ///
        (rcap ci_lo ci_hi xpos if outcome == "inctot_hh_real", lcolor(stc2)) ///
        (scatter coef xpos if outcome == "inctot_hh_real", mcolor(stc2) msymbol(D) msize(small)) ///
        (rcap ci_lo ci_hi xpos if outcome == "incother_hh_real", lcolor(stc3)) ///
        (scatter coef xpos if outcome == "incother_hh_real", mcolor(stc3) msymbol(T) msize(small)) ///
        , ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        xline(`xline_pos', lcolor(gs6)) ///
        ytitle("PPML Coefficient") ///
        xtitle("") ///
        xlabel(`xlabs', nogrid labsize(small)) ///
        ylabel(-.3(.1).3, angle(0) labsize(small)) ///
        legend(order(2 "Own Earnings" 4 "Total HH Income" 6 "Other HH Income") ///
               rows(1) position(6) size(small))

    ** Export combined figure
    export_graph, filename("fig_event_earn")

    ** -------------------------------------------------------------------------
    ** Version without Other HH Income (just Own Earnings and Total HH Income)
    ** -------------------------------------------------------------------------

    ** Adjust x positions for two-series plot
    drop xpos
    gen xpos = year - ${start_year} + 1
    replace xpos = xpos - 0.1 if outcome == "incearn_real"
    replace xpos = xpos + 0.1 if outcome == "inctot_hh_real"

    ** Plot combined figure (two outcomes only, scheme-consistent)
    twoway ///
        (rcap ci_lo ci_hi xpos if outcome == "incearn_real", lcolor(stc1)) ///
        (scatter coef xpos if outcome == "incearn_real", mcolor(stc1) msymbol(O) msize(small)) ///
        (rcap ci_lo ci_hi xpos if outcome == "inctot_hh_real", lcolor(stc2)) ///
        (scatter coef xpos if outcome == "inctot_hh_real", mcolor(stc2) msymbol(D) msize(small)) ///
        , ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        xline(`xline_pos', lcolor(gs6)) ///
        ytitle("PPML Coefficient") ///
        xtitle("") ///
        xlabel(`xlabs', nogrid labsize(small)) ///
        ylabel(-.3(.1).3, angle(0) labsize(small)) ///
        legend(order(2 "Own Earnings" 4 "Total HH Income") ///
               rows(1) position(6) size(small))

    ** Export figure
    export_graph, filename("fig_event_earn_2")

    ** Export coefficients for reference
    export delimited "${results}tables/fig_event_earn_coefficients.csv", replace

restore

** =============================================================================
** End
** =============================================================================

clear
log close log_03_fig_event_earn
