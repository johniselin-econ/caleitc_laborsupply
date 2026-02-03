/*******************************************************************************
File Name:      03_tab_hh_earn.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Table 6
                Triple-difference estimates of the effect of the CalEITC
                on household annual earnings (OLS and PPML)

                Uses utility programs: load_baseline_sample, setup_did_vars,
                run_triple_diff, run_ppml_regression, add_spec_indicators,
                export_results

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_tab_hh_earn
log using "${logs}03_tab_hh_earn_log_${date}", name(log_03_tab_hh_earn) replace text

** =============================================================================
** Define outcome variable
** =============================================================================

local outcome "inctot_hh_real"

** =============================================================================
** Load data and setup
** =============================================================================

** Load baseline sample with household income variable
load_baseline_sample, varlist(`outcome' incearn_real)

** Handle missing household earned income
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
                controls($controls) ///
                fes($did_base) ///
                weightvar(weight) ///
                clustervar($clustervar)
    }
    else {
        eststo est_`m'_2: ///
            run_ppml_regression `outcome', ///
                treatvar(treated) ///
                controls($controls) ///
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
                controls($controls) ///
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
                controls($controls) ///
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
                controls($controls) ///
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
                controls($controls) ///
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
        filename("tab_hh_earn_`m'.tex") ///
        statslist(`stats_list') ///
        statsfmt(`stats_fmt') ///
        label1("`lb1'") label2("`lb2'") label3("`lb3'") label4("`lb4'") ///
        bdigits(`dig') sedigits(`dig')

    ** For first model, create spec indicators table
    if `m' == 1 {
        export_results est_`m'_1 est_`m'_2 est_`m'_3 est_`m'_4, ///
            filename("tab_hh_earn_end.tex") ///
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
log close log_03_tab_hh_earn
