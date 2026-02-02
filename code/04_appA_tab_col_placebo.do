/*******************************************************************************
File Name:      04_appA_tab_col_placebo.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix Table: College-Educated Sample
                Triple-difference estimates of the effect of the CalEITC on
                annual employment, restricted to women WITH a college degree.

                This is a falsification test - college-educated women are less
                likely to be eligible for the CalEITC due to higher earnings,
                so we should expect smaller or null effects.

                Uses utility programs: setup_did_vars, run_all_specs, export_results

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_tab_col_placebo
log using "${logs}04_appA_tab_col_placebo_log_${date}", ///
    name(log_04_appA_tab_col_placebo) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define control variables (exclude education since sample is homogeneous)
local controls "age_bracket minage_qc race_group hispanic hh_adult_ct"

** =============================================================================
** Load data and define sample
** =============================================================================

** Load ACS data - COLLEGE EDUCATED ONLY (education == 4)
** Note: Cannot use load_baseline_sample here due to different education restriction
use weight $outcomes `controls' $unemp $minwage qc_* year ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status education ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education == 4 & ///
        state_status > 0 & ///
        inrange(year, ${start_year}, ${end_year}) ///
    using "${data}final/acs_working_file.dta", clear

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

    ** Run all 4 specifications
    run_all_specs `out', ///
        estprefix(est_`out') ///
        treatvar(treated) ///
        controls(`controls') ///
        unempvar($unemp) ///
        minwagevar($minwage) ///
        fes($did_base) ///
        weightvar(weight) ///
        clustervar($clustervar) ///
        qcvar(qc_ct)

    ** Define statistics labels
    local stats_labels `" "  Observations" "  Adj. R-Square" "  Treated group mean in pre-period" "  Implied employment effect" "'

    ** Export table using utility
    export_results est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4, ///
        filename("tab_col_placebo_`ct'.tex") ///
        statslist($stats_list) ///
        statsfmt($stats_fmt) ///
        statslabels(`stats_labels')

    ** For first outcome, create spec indicators table
    if `ct' == 1 {
        local spec_labels `" "  Triple-Difference" "  Add Demographic Controls" "  Add Unemployment Controls" "  Add Minimum Wage Controls" "'

        export_results est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4, ///
            filename("tab_col_placebo_end.tex") ///
            statslist("s1 s2 s3 s4") ///
            statsfmt("%9s %9s %9s %9s") ///
            statslabels(`spec_labels') ///
            cellsnone
    }

    ** Update count
    local ct = `ct' + 1
}

** =============================================================================
** End
** =============================================================================

clear
log close log_04_appA_tab_col_placebo
