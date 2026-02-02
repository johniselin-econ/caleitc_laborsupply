/*******************************************************************************
File Name:      03_tab_main.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Table 2 and accompanying coefficient plot figure
                Triple-difference estimates of the effect of the CalEITC
                on annual employment.

                Uses utility programs: load_baseline_sample, setup_did_vars,
                run_all_specs, export_results, make_table_coefplot

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_tab_main
log using "${logs}03_tab_main_log_${date}", name(log_03_tab_main) replace text

** =============================================================================
** Load data and setup
** =============================================================================

** Load baseline sample using utility
load_baseline_sample

** Create DID variables using utility
setup_did_vars

** =============================================================================
** Run regressions and export tables
** =============================================================================

** Clear stored values
eststo clear

** Local count
local ct = 1

** Loop over outcome variables
foreach out of global outcomes {

    ** Scale outcome to percentage points
    replace `out' = `out' * 100

    ** Run all 4 specifications using utility
    run_all_specs `out', ///
        estprefix(est_`out') ///
        treatvar(treated) ///
        controls($controls) ///
        unempvar($unemp) ///
        minwagevar($minwage) ///
        fes($did_base) ///
        weightvar(weight) ///
        clustervar($clustervar) ///
        qcvar(qc_ct)

    ** Define statistics labels (compound quoted for esttab)
    local stats_labels `" "  Observations" "  Adj. R-Square" "  Treated group mean in pre-period" "  Implied employment effect" "'

    ** Export table using utility
    export_results est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4, ///
        filename("tab_main_`ct'.tex") ///
        statslist($stats_list) ///
        statsfmt($stats_fmt) ///
        statslabels(`stats_labels')

    ** For first outcome, create spec indicators table
    if `ct' == 1 {
        local spec_labels `" "  Triple-Difference" "  Add Demographic Controls" "  Add Unemployment Controls" "  Add Minimum Wage Controls" "'

        export_results est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4, ///
            filename("tab_main_end.tex") ///
            statslist("s1 s2 s3 s4") ///
            statsfmt("%9s %9s %9s %9s") ///
            statslabels(`spec_labels') ///
            cellsnone
    }

    ** Update count
    local ct = `ct' + 1

}

** =============================================================================
** Create coefficient plot figure (Figure for Table 2)
** =============================================================================

** Define outcome labels for panel titles (| separated)
local out_labels "Employed in last 12 months|Full-time in last 12 months|Part-time in last 12 months"

** Define specification labels (| separated)
local spec_labels "No Controls|Individual Controls|Add Unemployment|Add Minimum Wage"

** Create coefficient plot using utility
make_table_coefplot, ///
    outcomes(employed_y full_time_y part_time_y) ///
    outlabels(`out_labels') ///
    specprefix(est_) ///
    numspecs(4) ///
    speclabels(`spec_labels') ///
    ytitle("Effect of the CalEITC on employment (pp)") ///
    ymin(-5) ymax(5) ycut(2.5) ///
    savepath("${results}figures/fig_tab_main.png")

** Export graph using utility
export_graph, filename("fig_tab_main")

** =============================================================================
** End
** =============================================================================

clear
log close log_03_tab_main
