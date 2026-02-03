/*******************************************************************************
File Name:      04_appC_tab_self_emp.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix C Table 2
                Triple-difference estimates of the effect of the CalEITC on
                self-employment.

                Uses utility programs: load_baseline_sample, setup_did_vars,
                run_all_specs, export_results

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appC_tab_self_emp
log using "${logs}04_appC_tab_self_emp_log_${date}", ///
    name(log_04_appC_tab_self_emp) replace text

** =============================================================================
** Define custom outcomes for this analysis
** =============================================================================

local outcomes "self_employed_w any_incse_real any_incse_real_1k"

** =============================================================================
** Load data and setup
** =============================================================================

** Load baseline sample with self-employment variables
load_baseline_sample, varlist(self_employed_w incse_real)

** Create DID variables using utility
setup_did_vars

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
** Run regressions and export tables
** =============================================================================

** Clear stored values
eststo clear

** Local count
local ct = 1

** Loop over outcome variables
foreach out of local outcomes {

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

    ** Export table using utility
    export_results est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4, ///
        filename("tab_appC_tab2_`ct'.tex") ///
        statslist($stats_list) ///
        statsfmt($stats_fmt) ///
        label1("  Observations") ///
        label2("  Adj. R-Square") ///
        label3("  Treated group mean in pre-period") ///
        label4("  Implied employment effect")

    ** For first outcome, create spec indicators table
    if `ct' == 1 {
        export_spec_indicators est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4, ///
            outfile("${results}tables/tab_appC_tab2_end.tex")

        if ${overleaf} == 1 {
            export_spec_indicators est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4, ///
                outfile("${ol_tab}tab_appC_tab2_end.tex")
        }
    }

    ** Update count
    local ct = `ct' + 1

}

** =============================================================================
** End
** =============================================================================

clear
log close log_04_appC_tab_self_emp
