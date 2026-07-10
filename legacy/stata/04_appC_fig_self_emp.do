/*******************************************************************************
File Name:      04_appC_fig_self_emp.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix C Figure 2
                Event-study estimates of the effect of the CalEITC on annual
                self-employment.

                Uses utility programs: load_baseline_sample, setup_did_vars,
                run_event_study, make_event_plot, export_graph

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appC_fig_self_emp
log using "${logs}04_appC_fig_self_emp_log_${date}", ///
    name(log_04_appC_fig_self_emp) replace text

** =============================================================================
** Define custom outcomes for this analysis
** =============================================================================

local outcomes "self_employed_w any_incse_real any_incse_real_1k"

** =============================================================================
** Load data and setup
** =============================================================================

** Load baseline sample with self-employment variables
load_baseline_sample, varlist(self_employed_w incse_real)

** Create DID variables (including event study variable)
setup_did_vars, eventstudy

** =============================================================================
** Create self-employment income variables
** =============================================================================

** Generate $1K+ self-employment income indicator
gen tmp = incse_real
replace tmp = 0 if missing(incse_real)
replace tmp = 0 if tmp == 999999
gen byte any_incse_real = (tmp > 0)
gen byte any_incse_real_1k = (tmp >= 1000)
label var any_incse_real "Any self-employment income last year"
label var any_incse_real_1k "$1K+ self-employment income last year"
drop tmp

** Label minimum wage variable
label var mean_st_mw "Binding state minimum wage"

** =============================================================================
** Run event-study regressions
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
            controls($controls) ///
            unempvar($unemp) ///
            minwagevar($minwage) ///
            fes($did_event) ///
            weightvar(weight) ///
            clustervar($clustervar) ///
            qcvar(qc_ct)
}

** =============================================================================
** Create coefficient plot
** =============================================================================

** Create coefficient plot
make_event_plot est_self_employed_w est_any_incse_real est_any_incse_real_1k, ///
    eventvar(childXyearXca) ///
    startyear(${start_year}) ///
    endyear(${end_year}) ///
    baseyear(2014) ///
    ymax(6) ///
    ycut(2) ///
    savepath("${results}figures/fig_appC_fig2.jpg") ///
    labels(Self-employed|Any SE income|At least $1,000 in SE income)

** Export graph using utility
export_graph, filename("fig_appC_self_emp")

** =============================================================================
** End
** =============================================================================

log close log_04_appC_fig_self_emp
