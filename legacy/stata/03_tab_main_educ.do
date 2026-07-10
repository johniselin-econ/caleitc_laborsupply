/*******************************************************************************
File Name:      03_tab_main_educ.do
Creator:        John Iselin
Date Update:    July 2026

Purpose:        Produces tab_main_educ_{1,2,3}.tex and tab_main_educ_end.tex:
                within-California triple-difference using education
                (non-college vs. college) in place of the state dimension:

                    treated = nocollege x qc_present x post,  CA only

                Column structure:
                  (1) Triple-Difference FEs (4-level education interactions)
                  (2) + County FEs
                  (3) + Demographic Controls

                RECOVERED July 2026 from the original run log
                (03_tab_main_educ_log_2026-03-05.log): the do-file was lost
                from the repo, but the log echoes the full script. This file
                is a faithful transcription. Key design points confirmed by
                the log: triple-diff FEs interact the FULL 4-level education
                variable (qc_ct#education, year#education), not the binary
                no-college indicator; spec 1 has no county FEs; SEs cluster
                on county_fips (35 clusters).

                VALIDATION TARGETS (from the 2026-03-05 log; identical
                acs_working_file vintage as the current rebuild, CA N=132,910):
                  Employed:  1.771 (0.905) | 1.748 (0.901) | 1.510 (0.989)
                  Full-time: 1.117 (1.192) | 1.029 (1.174) | 0.696 (1.177)
                  Part-time: 0.654 (0.856) | 0.718 (0.844) | 0.813 (0.877)
                  Adj. R2 (employed): 0.0986 | 0.1042 | 0.1195
                  ymeans: 71.645 / 51.290 / 20.355

                Uses utility programs: run_triple_diff, add_table_stats,
                add_spec_indicators, export_results, make_table_coefplot,
                export_graph

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_tab_main_educ
log using "${logs}03_tab_main_educ_log_${date}", ///
    name(log_03_tab_main_educ) replace text

** =============================================================================
** Load data — CA only, all education levels
** =============================================================================

** Variables to load
local outcomes "employed_y full_time_y part_time_y"
local controls "age_bracket minage_qc race_group hispanic hh_adult_ct"

use weight `outcomes' `controls' state_unemp mean_st_mw qc_* year ///
    female married in_school age_sample_20_49 citizen_test ///
    state_fips county_fips education ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        state_fips == 6 & ///
        inrange(year, ${start_year}, ${end_year}) ///
    using "${data}final/acs_working_file.dta", clear

di _n "Loaded CA-only sample (all education levels): N = " _N

** =============================================================================
** Create DID variables
** =============================================================================

** No-college indicator (education < 4)
gen nocollege = (education < 4)

** Post-period indicator
gen post = (year > 2014)

** Treatment indicator: no-college x QC x post
gen treated = (nocollege == 1 & qc_present == 1 & post == 1)
label var treated "ATE"

** Cap adults per HH at 3
replace hh_adult_ct = 3 if hh_adult_ct > 3
capture label drop lb_adult_ct
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** Triple-diff FEs: education replaces state as 3rd dimension
local did_base "qc_ct year education qc_ct#year qc_ct#education year#education"

** =============================================================================
** Run regressions and export tables
** =============================================================================

eststo clear

local ct = 1

foreach out of local outcomes {

    ** Scale outcome to percentage points
    replace `out' = `out' * 100

    ** -----------------------------------------------------------------
    ** SPEC 1: Basic triple-diff FEs only
    ** -----------------------------------------------------------------
    eststo est_`out'_1: ///
        run_triple_diff `out', ///
            treatvar(treated) ///
            fes(`did_base') ///
            weightvar(weight) ///
            clustervar(county_fips)

    add_table_stats, outcome(`out') treatvar(treated) ///
        postvar(post) statevar(nocollege) qcvar(qc_present) ///
        weightvar(weight)
    add_spec_indicators, spec(1)

    ** -----------------------------------------------------------------
    ** SPEC 2: Add county FEs
    ** -----------------------------------------------------------------
    eststo est_`out'_2: ///
        run_triple_diff `out', ///
            treatvar(treated) ///
            fes(`did_base' county_fips) ///
            weightvar(weight) ///
            clustervar(county_fips)

    add_table_stats, outcome(`out') treatvar(treated) ///
        postvar(post) statevar(nocollege) qcvar(qc_present) ///
        weightvar(weight)
    add_spec_indicators, spec(2)

    ** -----------------------------------------------------------------
    ** SPEC 3: Add demographic controls
    ** -----------------------------------------------------------------
    eststo est_`out'_3: ///
        run_triple_diff `out', ///
            treatvar(treated) ///
            controls(`controls') ///
            fes(`did_base' county_fips) ///
            weightvar(weight) ///
            clustervar(county_fips)

    add_table_stats, outcome(`out') treatvar(treated) ///
        postvar(post) statevar(nocollege) qcvar(qc_present) ///
        weightvar(weight)
    add_spec_indicators, spec(3)

    ** -----------------------------------------------------------------
    ** Export table panel
    ** -----------------------------------------------------------------
    export_results est_`out'_1 est_`out'_2 est_`out'_3, ///
        filename("tab_main_educ_`ct'.tex") ///
        statslist($stats_list) ///
        statsfmt($stats_fmt) ///
        label1("  Observations") ///
        label2("  Adj. R-Square") ///
        label3("  Treated group mean in pre-period") ///
        label4("  Implied employment effect")

    ** For first outcome, create spec indicators table
    if `ct' == 1 {
        export_results est_`out'_1 est_`out'_2 est_`out'_3, ///
            filename("tab_main_educ_end.tex") ///
            statslist("s1 s2 s3") ///
            statsfmt("%9s %9s %9s") ///
            label1("  Triple-Difference FEs") ///
            label2("  County FEs") ///
            label3("  Demographic Controls") ///
            cellsnone
    }

    local ct = `ct' + 1

}

** =============================================================================
** Create coefficient plot figure
** =============================================================================

** Define outcome labels for panel titles (| separated)
local out_labels "Employed in last 12 months|Full-time in last 12 months|Part-time in last 12 months"

** Define specification labels (| separated)
local spec_labels "No Controls|County FEs|Add Demographics"

** Create coefficient plot using utility
make_table_coefplot, ///
    outcomes(employed_y full_time_y part_time_y) ///
    outlabels(`out_labels') ///
    specprefix(est_) ///
    numspecs(3) ///
    speclabels(`spec_labels') ///
    ytitle("Effect of the CalEITC on employment (pp)") ///
    ymin(-5) ymax(5) ycut(2.5) ///
    savepath("${results}figures/fig_tab_main_educ.png")

** Export graph using utility
export_graph, filename("fig_tab_main_educ")

** =============================================================================
** End
** =============================================================================

clear
log close log_03_tab_main_educ
