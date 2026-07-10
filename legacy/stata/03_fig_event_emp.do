/*******************************************************************************
File Name:      03_fig_event_emp.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Figure 5
                Event-study estimates of the effect of the CalEITC
                on annual employment.

                Uses utility programs: load_baseline_sample, setup_did_vars,
                run_event_study, make_event_plot, export_event_coefficients,
                export_graph

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_event_emp
log using "${logs}03_fig_event_emp_log_${date}", name(log_03_fig_event_emp) replace text

** =============================================================================
** Load data and setup
** =============================================================================

** Load baseline sample using utility
load_baseline_sample

** Create DID variables (including event study variable)
setup_did_vars, eventstudy

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

** Create coefficient plot using utility program
make_event_plot est_employed_y est_full_time_y est_part_time_y, ///
    eventvar(childXyearXca) ///
    startyear(${start_year}) ///
    endyear(${end_year}) ///
    baseyear(2014) ///
    ymax(6) ///
    ycut(2) ///
    savepath("${results}figures/fig_event_emp.jpg") ///
    labels(Employed|Employed full-time|Employed part-time)

** Export graph using utility
export_graph, filename("fig_event_emp")

** =============================================================================
** Export coefficients for reference
** =============================================================================

export_event_coefficients est_employed_y est_full_time_y est_part_time_y, ///
    eventvar(childXyearXca) ///
    startyear(${start_year}) ///
    endyear(${end_year}) ///
    baseyear(2014) ///
    outfile("${results}tables/fig_event_emp_coefficients.csv")

** =============================================================================
** End
** =============================================================================

log close log_03_fig_event_emp
