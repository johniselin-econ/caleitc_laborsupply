/*******************************************************************************
File Name:      04_appA_tab_alt_threshold.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix Table: Alternative Full-Time Thresholds
                Triple-difference estimates of the effect of the CalEITC
                on annual employment using alternative definitions of
                full-time work (31 hours and 39 hours instead of 35 hours).

                Uses utility programs: load_baseline_sample, setup_did_vars,
                run_all_specs, export_results

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_tab_alt_threshold
log using "${logs}04_appA_tab_alt_threshold_log_${date}", ///
    name(log_04_appA_tab_alt_threshold) replace text

** =============================================================================
** PANEL A: 31-Hour Threshold
** =============================================================================

** Load baseline sample with alternative measures
load_baseline_sample, varlist(full_time_y_31 part_time_y_31)

** Create DID variables using utility
setup_did_vars

** Clear stored values
eststo clear

** Local count
local ct = 1

** Define outcomes for 31-hour threshold
local outcomes_31 "employed_y full_time_y_31 part_time_y_31"

** Loop over outcome variables
foreach out of local outcomes_31 {

    ** Scale outcome to percentage points
    replace `out' = `out' * 100

    ** Run all 4 specifications using utility
    run_all_specs `out', ///
        estprefix(est_31_`out') ///
        treatvar(treated) ///
        controls($controls) ///
        unempvar($unemp) ///
        minwagevar($minwage) ///
        fes($did_base) ///
        weightvar(weight) ///
        clustervar($clustervar) ///
        qcvar(qc_ct)

    ** Export table using utility
    export_results est_31_`out'_1 est_31_`out'_2 est_31_`out'_3 est_31_`out'_4, ///
        filename("tab_alt_threshold_31_`ct'.tex") ///
        statslist($stats_list) ///
        statsfmt($stats_fmt) ///
        label1("  Observations") ///
        label2("  Adj. R-Square") ///
        label3("  Treated group mean in pre-period") ///
        label4("  Implied employment effect")

    ** For first outcome, create spec indicators table
    if `ct' == 1 {
        export_results est_31_`out'_1 est_31_`out'_2 est_31_`out'_3 est_31_`out'_4, ///
            filename("tab_alt_threshold_31_end.tex") ///
            statslist("s1 s2 s3 s4") ///
            statsfmt("%9s %9s %9s %9s") ///
            label1("  Triple-Difference") ///
            label2("  Add Demographic Controls") ///
            label3("  Add Unemployment Controls") ///
            label4("  Add Minimum Wage Controls") ///
            cellsnone
    }

    ** Update count
    local ct = `ct' + 1
}

** =============================================================================
** PANEL B: 39-Hour Threshold
** =============================================================================

** Load baseline sample with alternative measures
load_baseline_sample, varlist(full_time_y_39 part_time_y_39)

** Create DID variables using utility
setup_did_vars

** Clear stored values
eststo clear

** Local count
local ct = 1

** Define outcomes for 39-hour threshold
local outcomes_39 "employed_y full_time_y_39 part_time_y_39"

** Loop over outcome variables
foreach out of local outcomes_39 {

    ** Scale outcome to percentage points
    replace `out' = `out' * 100

    ** Run all 4 specifications using utility
    run_all_specs `out', ///
        estprefix(est_39_`out') ///
        treatvar(treated) ///
        controls($controls) ///
        unempvar($unemp) ///
        minwagevar($minwage) ///
        fes($did_base) ///
        weightvar(weight) ///
        clustervar($clustervar) ///
        qcvar(qc_ct)

    ** Export table using utility
    export_results est_39_`out'_1 est_39_`out'_2 est_39_`out'_3 est_39_`out'_4, ///
        filename("tab_alt_threshold_39_`ct'.tex") ///
        statslist($stats_list) ///
        statsfmt($stats_fmt) ///
        label1("  Observations") ///
        label2("  Adj. R-Square") ///
        label3("  Treated group mean in pre-period") ///
        label4("  Implied employment effect")

    ** For first outcome, create spec indicators table
    if `ct' == 1 {
        export_results est_39_`out'_1 est_39_`out'_2 est_39_`out'_3 est_39_`out'_4, ///
            filename("tab_alt_threshold_39_end.tex") ///
            statslist("s1 s2 s3 s4") ///
            statsfmt("%9s %9s %9s %9s") ///
            label1("  Triple-Difference") ///
            label2("  Add Demographic Controls") ///
            label3("  Add Unemployment Controls") ///
            label4("  Add Minimum Wage Controls") ///
            cellsnone
    }

    ** Update count
    local ct = `ct' + 1
}

** =============================================================================
** End
** =============================================================================

clear
log close log_04_appA_tab_alt_threshold
