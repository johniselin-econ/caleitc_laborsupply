/*******************************************************************************
File Name:      04_appA_tab_col_placebo_earn.do
Creator:        John Iselin
Date Update:    March 2026

Purpose:        Creates Appendix Table: Earnings Placebo — College-Educated Sample
                Triple-difference estimates of the effect of the CalEITC on
                annual earnings, restricted to women WITH a college degree.

                This is a falsification test — college-educated women are less
                likely to be eligible for the CalEITC, so we should expect
                smaller or null effects on earnings.

                Uses utility programs: setup_did_vars, run_triple_diff,
                run_ppml_regression, add_spec_indicators, export_results

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_tab_col_placebo_earn
log using "${logs}04_appA_tab_col_placebo_earn_log_${date}", ///
    name(log_04_appA_tab_col_placebo_earn) replace text

** =============================================================================
** Define outcome variable
** =============================================================================

local outcome "incearn_real"

** Define control variables (exclude education since sample is homogeneous)
local controls "age_bracket minage_qc race_group hispanic hh_adult_ct"

** =============================================================================
** Load data and define sample
** =============================================================================

** Load ACS data - COLLEGE EDUCATED ONLY (education == 4)
** Note: Cannot use load_baseline_sample here due to different education restriction
use weight `outcome' `controls' $unemp $minwage qc_* year ///
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

** Handle missing earned income
replace `outcome' = 0 if `outcome' == .

** Create DID variables using utility
setup_did_vars

** =============================================================================
** Run regressions and export tables
** =============================================================================

** Clear stored values
eststo clear

** Loop over models (1=OLS all, 2=OLS positive, 3=PPML)
forvalues m = 1/3 {

    ** Define sample conditions
    if `m' == 1 gen sample = `outcome' >= 0 & !missing(`outcome')
    if `m' == 2 gen sample = `outcome' > 0 & !missing(`outcome')
    if `m' == 3 gen sample = `outcome' >= 0 & !missing(`outcome')

    ** SPEC 1: Basic triple-diff FEs only
    if `m' < 3 {
        eststo est_`m'_1: ///
            run_triple_diff `outcome' if sample == 1, ///
                treatvar(treated) ///
                fes($did_base) ///
                weightvar(weight) ///
                clustervar($clustervar)
    }
    else {
        eststo est_`m'_1: ///
            run_ppml_regression `outcome', ///
                treatvar(treated) ///
                fes($did_base) ///
                weightvar(weight) ///
                clustervar($clustervar) ///
                samplecond(sample == 1)
        estadd scalar AME = r(AME)
    }

    ** Get pre-period treated mean
    qui summ `outcome' if sample == 1 & post == 0 & ca == 1 & qc_present == 1 [aw=weight]
    estadd scalar ymean = r(mean)
    add_spec_indicators, spec(1)

    ** SPEC 2: Add demographic controls
    if `m' < 3 {
        eststo est_`m'_2: ///
            run_triple_diff `outcome' if sample == 1, ///
                treatvar(treated) ///
                controls(`controls') ///
                fes($did_base) ///
                weightvar(weight) ///
                clustervar($clustervar)
    }
    else {
        eststo est_`m'_2: ///
            run_ppml_regression `outcome', ///
                treatvar(treated) ///
                controls(`controls') ///
                fes($did_base) ///
                weightvar(weight) ///
                clustervar($clustervar) ///
                samplecond(sample == 1)
        estadd scalar AME = r(AME)
    }

    qui summ `outcome' if sample == 1 & post == 0 & ca == 1 & qc_present == 1 [aw=weight]
    estadd scalar ymean = r(mean)
    add_spec_indicators, spec(2)

    ** SPEC 3: Add unemployment controls
    if `m' < 3 {
        eststo est_`m'_3: ///
            run_triple_diff `outcome' if sample == 1, ///
                treatvar(treated) ///
                controls(`controls') ///
                unempvar($unemp) ///
                fes($did_base) ///
                weightvar(weight) ///
                clustervar($clustervar) ///
                qcvar(qc_ct)
    }
    else {
        eststo est_`m'_3: ///
            run_ppml_regression `outcome', ///
                treatvar(treated) ///
                controls(`controls') ///
                unempvar($unemp) ///
                fes($did_base) ///
                weightvar(weight) ///
                clustervar($clustervar) ///
                qcvar(qc_ct) ///
                samplecond(sample == 1)
        estadd scalar AME = r(AME)
    }

    qui summ `outcome' if sample == 1 & post == 0 & ca == 1 & qc_present == 1 [aw=weight]
    estadd scalar ymean = r(mean)
    add_spec_indicators, spec(3)

    ** SPEC 4: Add minimum wage controls
    if `m' < 3 {
        eststo est_`m'_4: ///
            run_triple_diff `outcome' if sample == 1, ///
                treatvar(treated) ///
                controls(`controls') ///
                unempvar($unemp) ///
                minwagevar($minwage) ///
                fes($did_base) ///
                weightvar(weight) ///
                clustervar($clustervar) ///
                qcvar(qc_ct)
    }
    else {
        eststo est_`m'_4: ///
            run_ppml_regression `outcome', ///
                treatvar(treated) ///
                controls(`controls') ///
                unempvar($unemp) ///
                minwagevar($minwage) ///
                fes($did_base) ///
                weightvar(weight) ///
                clustervar($clustervar) ///
                qcvar(qc_ct) ///
                samplecond(sample == 1)
        estadd scalar AME = r(AME)
    }

    qui summ `outcome' if sample == 1 & post == 0 & ca == 1 & qc_present == 1 [aw=weight]
    estadd scalar ymean = r(mean)
    add_spec_indicators, spec(4)

    ** Define statistics and formatting for export
    if `m' < 3 {
        local stats_list "N r2_a ymean"
        local stats_fmt "%9.0fc %9.3fc %9.0fc"
        local dig = 1
        local lb1 "  Observations"
        local lb2 "  Adj. R-Square"
        local lb3 "  Treated group mean in pre-period"
        local lb4 ""
    }
    else {
        local stats_list "N r2_p ymean AME"
        local stats_fmt "%9.0fc %9.3fc %9.0fc %9.0fc"
        local dig = 2
        local lb1 "  Observations"
        local lb2 "  Pseudo R-squared"
        local lb3 "  Treated group mean in pre-period"
        local lb4 "  Effect in USD"
    }

    ** Export table using utility
    export_results est_`m'_1 est_`m'_2 est_`m'_3 est_`m'_4, ///
        filename("tab_col_placebo_earn_`m'.tex") ///
        statslist(`stats_list') ///
        statsfmt(`stats_fmt') ///
        label1("`lb1'") label2("`lb2'") label3("`lb3'") label4("`lb4'") ///
        bdigits(`dig') sedigits(`dig')

    ** For first model, create spec indicators table
    if `m' == 1 {
        export_results est_`m'_1 est_`m'_2 est_`m'_3 est_`m'_4, ///
            filename("tab_col_placebo_earn_end.tex") ///
            statslist("s1 s2 s3 s4") ///
            statsfmt("%9s %9s %9s %9s") ///
            label1("  Triple-Difference") ///
            label2("  Add Demographic Controls") ///
            label3("  Add Unemployment Controls") ///
            label4("  Add Minimum Wage Controls") ///
            cellsnone
    }

    ** Drop sample variable
    drop sample

}

** =============================================================================
** End
** =============================================================================

clear
log close log_04_appA_tab_col_placebo_earn
