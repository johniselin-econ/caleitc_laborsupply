/*******************************************************************************
File Name:      04_appC_fig_wage_emp.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix C Figure 1
                Event-study estimates of the effect of the CalEITC on annual
                employment, restricted to wage-workers.

                Uses utility programs: load_baseline_sample, setup_did_vars,
                run_event_study, make_event_plot, export_graph

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appC_fig_wage_emp
log using "${logs}04_appC_fig_wage_emp_log_${date}", ///
    name(log_04_appC_fig_wage_emp) replace text

** =============================================================================
** Load data and setup
** =============================================================================

** Load baseline sample with wage variable
load_baseline_sample, varlist(incwage_real)

** Create DID variables (including event study variable)
setup_did_vars, eventstudy

** =============================================================================
** Restrict sample to wage workers
** =============================================================================

** Update outcomes for wage earnings only
replace incwage_real = 0 if incwage_real == .
gen any_wage = (incwage_real > 0)

** Adjust outcomes to only count those with wage income
foreach out of global outcomes {
    replace `out' = (`out' == 1 & any_wage == 1)
}

** Label minimum wage variable
label var mean_st_mw "Binding state minimum wage"

** =============================================================================
** Run event-study regressions
** =============================================================================

** Loop over outcome variables
foreach out of global outcomes {

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
make_event_plot est_employed_y est_full_time_y est_part_time_y, ///
    eventvar(childXyearXca) ///
    startyear(${start_year}) ///
    endyear(${end_year}) ///
    baseyear(2014) ///
    ymax(6) ///
    ycut(2) ///
    savepath("${results}figures/fig_appC_fig1.jpg") ///
    labels(Employed|Employed full-time|Employed part-time)

** Export graph using utility
export_graph, filename("fig_appC_wage_emp")

** =============================================================================
** End
** =============================================================================

log close log_04_appC_fig_wage_emp
