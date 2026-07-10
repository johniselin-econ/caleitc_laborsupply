/*******************************************************************************
File Name:      03_tab_het_adults.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Table 4
                Triple-difference estimates of the effect of the CalEITC
                on annual employment, by count of adults in HH

                Uses utility programs: load_baseline_sample, setup_did_vars,
                run_heterogeneity_table, export_results, make_table_coefplot

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_tab_het_adults
log using "${logs}03_tab_het_adults_log_${date}", name(log_03_tab_het_adults) replace text

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

    ** Run heterogeneity analysis (0=all, 1-3=by adult count)
    forvalues i = 1/4 {

        ** Update h local
        local h = `i' - 1

        ** Define sample
        if `h' == 0 gen samp = 1
        else gen samp = hh_adult_ct == `h'

        ** Run triple-difference regression with full controls
        eststo est_`out'_`i': ///
            run_triple_diff `out' if samp == 1, ///
                treatvar(treated) ///
                controls($controls) ///
                unempvar($unemp) ///
                minwagevar($minwage) ///
                fes($did_base) ///
                weightvar(weight) ///
                clustervar($clustervar) ///
                qcvar(qc_ct)

        add_table_stats, outcome(`out') treatvar(treated) ///
            postvar(post) statevar(ca) qcvar(qc_present) weightvar(weight) ///
            samplecond(samp == 1)
        add_spec_indicators, spec(4)

        ** Drop sample variable
        drop samp

    }

    ** Export table using utility
    export_results est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4, ///
        filename("tab_het_adults_`ct'.tex") ///
        statslist($stats_list) ///
        statsfmt($stats_fmt) ///
        label1("  Observations") ///
        label2("  Adj. R-Square") ///
        label3("  Treated group mean in pre-period") ///
        label4("  Implied employment effect")

    ** For first outcome, create column indicators table
    if `ct' == 1 {
        export_results est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4, ///
            filename("tab_het_adults_end.tex") ///
            statslist("s1 s2 s3 s4") ///
            statsfmt("%9s %9s %9s %9s") ///
            label1("  Full Sample") ///
            label2("  1 Adult") ///
            label3("  2 Adults") ///
            label4("  3+ Adults") ///
            cellsnone
    }

    ** Update count
    local ct = `ct' + 1

}

** =============================================================================
** Create coefficient plot figure
** =============================================================================

** Define outcome labels for panel titles (| separated)
local out_labels "Employed in last 12 months|Full-time in last 12 months|Part-time in last 12 months"

** Define specification labels (| separated)
local spec_labels "All|1 Adult|2 Adults|3+ Adults"

** Create coefficient plot using utility
make_table_coefplot, ///
    outcomes(employed_y full_time_y part_time_y) ///
    outlabels(`out_labels') ///
    specprefix(est_) ///
    numspecs(4) ///
    speclabels(`spec_labels') ///
    ytitle("Effect of the CalEITC on employment (pp)") ///
    ymin(-7.5) ymax(7.5) ycut(2.5) ///
    savepath("${results}figures/fig_tab_het_adults.png")

** Export graph using utility
export_graph, filename("fig_tab_het_adults")

** =============================================================================
** End
** =============================================================================

clear
log close log_03_tab_het_adults
