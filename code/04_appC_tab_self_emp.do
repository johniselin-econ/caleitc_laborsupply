/*******************************************************************************
File Name:      04_appC_tab_self_emp.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix C Table 2
                Triple-difference estimates of the effect of the CalEITC on
                self-employment.

                Uses utility programs: run_triple_diff, add_spec_indicators,
                add_table_stats

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appC_tab_self_emp
log using "${logs}04_appC_tab_self_emp_log_${date}", ///
    name(log_04_appC_tab_self_emp) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define outcome variables (original + created)
local outcomes_load "self_employed_w incse_real"
local outcomes "self_employed_w any_incse_real any_incse_real_1k"

** Define control variables
local controls "education age_bracket minage_qc race_group hispanic hh_adult_ct"

** Define unemployment control variable
local unemp "state_unemp"

** Define minimum wage control variable
local minwage "mean_st_mw"

** Define cluster variable
local clustervar "state_fips"

** Define start and end dates
local start = 2012
local end = ${end_year}

** Base fixed effects
local did_base "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"

** =============================================================================
** Load data and define sample
** =============================================================================

** Load ACS data
use weight `outcomes_load' `controls' `unemp' `minwage' qc_* year  ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", clear

** Create main DID variables
gen ca = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)
label var treated "ATE"

** Update adults per HH (cap at 3)
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** =============================================================================
** Create self-employment income variable
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

** Local count
local ct = 1

** Clear stored values
eststo clear

** Loop over outcome variables
foreach out of local outcomes {

    ** Scale outcome to percentage points
    replace `out' = `out' * 100

    ** SPEC 1: Basic triple-diff FEs only
    eststo est_`out'_1: ///
        run_triple_diff `out', ///
            treatvar(treated) ///
            fes(`did_base') ///
            weightvar(weight) ///
            clustervar(`clustervar')

    add_table_stats, outcome(`out') treatvar(treated) ///
        postvar(post) statevar(ca) qcvar(qc_present) weightvar(weight)
    add_spec_indicators, spec(1)

    ** SPEC 2: Add demographic controls
    eststo est_`out'_2: ///
        run_triple_diff `out', ///
            treatvar(treated) ///
            controls(`controls') ///
            fes(`did_base') ///
            weightvar(weight) ///
            clustervar(`clustervar')

    add_table_stats, outcome(`out') treatvar(treated) ///
        postvar(post) statevar(ca) qcvar(qc_present) weightvar(weight)
    add_spec_indicators, spec(2)

    ** SPEC 3: Add unemployment controls
    eststo est_`out'_3: ///
        run_triple_diff `out', ///
            treatvar(treated) ///
            controls(`controls') ///
            unempvar(`unemp') ///
            fes(`did_base') ///
            weightvar(weight) ///
            clustervar(`clustervar') ///
            qcvar(qc_ct)

    add_table_stats, outcome(`out') treatvar(treated) ///
        postvar(post) statevar(ca) qcvar(qc_present) weightvar(weight)
    add_spec_indicators, spec(3)

    ** SPEC 4: Add minimum wage controls
    eststo est_`out'_4: ///
        run_triple_diff `out', ///
            treatvar(treated) ///
            controls(`controls') ///
            unempvar(`unemp') ///
            minwagevar(`minwage') ///
            fes(`did_base') ///
            weightvar(weight) ///
            clustervar(`clustervar') ///
            qcvar(qc_ct)

    add_table_stats, outcome(`out') treatvar(treated) ///
        postvar(post) statevar(ca) qcvar(qc_present) weightvar(weight)
    add_spec_indicators, spec(4)

    ** =========================================================================
    ** Export table for this outcome
    ** =========================================================================

    ** Define statistics
    local stats_list "N r2_a ymean C"
    local stats_fmt "%9.0fc %9.3fc %9.1fc %9.0fc"

    ** Define statistics labels
    local stats_labels `" "  Observations" "'
    local stats_labels `" `stats_labels' "  Adj. R-Square" "'
    local stats_labels `" `stats_labels' "  Treated group mean in pre-period" "'
    local stats_labels `" `stats_labels' "  Implied employment effect" "'

    ** Save table locally
    esttab est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4 using ///
        "${results}tables/tab_appC_tab2_`ct'.tex", ///
        booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
        stats(`stats_list', ///
            fmt("`stats_fmt'") ///
            labels(`stats_labels')) ///
        b(1) se(1) label order(treated) keep(treated) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        prehead("\\ \midrule")

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        esttab est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4 using ///
            "${ol_tab}tab_appC_tab2_`ct'.tex", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
            stats(`stats_list', ///
                fmt("`stats_fmt'") ///
                labels(`stats_labels')) ///
            b(1) se(1) label order(treated) keep(treated) ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("\\ \midrule")
    }

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
