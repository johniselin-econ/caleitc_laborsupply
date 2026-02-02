/*******************************************************************************
File Name:      04_appendix_otherpops.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates appendix tables and figures for alternative populations

                (1) Triple-difference estimates across different samples:
                    - Single women (main sample)
                    - Single men
                    - Married women
                    - Married men
                    Two versions: no covariates (spec 1) and all covariates (spec 4)

                (2) Event-study figures for each sample (spec 4)

                Uses utility programs: setup_did_vars, run_triple_diff,
                add_spec_indicators, add_table_stats, run_event_study,
                make_event_plot, export_results, export_graph,
                export_event_coefficients

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appendix_otherpops
log using "${logs}04_appendix_otherpops_log_${date}", name(log_04_appendix_otherpops) replace text

** =============================================================================
** Define population conditions
** =============================================================================

** Define populations and their conditions
local pops "sw sm mw mm"
local pop_sw_fem = 1
local pop_sw_mar = 0
local pop_sw_name "Single Women"

local pop_sm_fem = 0
local pop_sm_mar = 0
local pop_sm_name "Single Men"

local pop_mw_fem = 1
local pop_mw_mar = 1
local pop_mw_name "Married Women"

local pop_mm_fem = 0
local pop_mm_mar = 1
local pop_mm_name "Married Men"

** =============================================================================
** PART 1: TABLES BY POPULATION
** =============================================================================

** Loop over specifications (1 = no controls, 4 = all controls)
foreach spec in 1 4 {

    ** Set specification label for filenames
    if `spec' == 1 local spec_lbl "nocov"
    else local spec_lbl "allcov"

    dis ""
    dis "=============================================="
    dis "Running tables for specification: `spec_lbl'"
    dis "=============================================="

    ** Clear stored estimates
    eststo clear

    ** Loop over outcome variables
    local ct = 1
    foreach out of global outcomes {

        dis ""
        dis "Outcome: `out'"
        dis "----------------------------------------------"

        ** Loop over populations
        local pop_ct = 1
        foreach pop of local pops {

            ** Get population conditions
            local fem_val = `pop_`pop'_fem'
            local mar_val = `pop_`pop'_mar'
            local pop_name "`pop_`pop'_name'"

            dis "  Population: `pop_name'"

            ** Load ACS data with sample restrictions
            use weight $outcomes $controls $unemp $minwage qc_* year ///
                female married in_school age_sample_20_49 citizen_test state_fips state_status ///
                if  female == `fem_val' & ///
                    married == `mar_val' & ///
                    in_school == 0 & ///
                    age_sample_20_49 == 1 & ///
                    citizen_test == 1 & ///
                    education < 4 & ///
                    state_status > 0 & ///
                    inrange(year, ${start_year}, ${end_year}) ///
                using "${data}final/acs_working_file.dta", clear

            ** Create DID variables
            setup_did_vars, treatlabel("`pop_name'")

            ** Scale outcome to percentage points
            replace `out' = `out' * 100

            ** Run regression based on specification
            if `spec' == 1 {
                ** SPEC 1: Basic triple-diff FEs only
                eststo est_`out'_`pop': ///
                    run_triple_diff `out', ///
                        treatvar(treated) ///
                        fes($did_base) ///
                        weightvar(weight) ///
                        clustervar($clustervar)
            }
            else {
                ** SPEC 4: All covariates
                eststo est_`out'_`pop': ///
                    run_triple_diff `out', ///
                        treatvar(treated) ///
                        controls($controls) ///
                        unempvar($unemp) ///
                        minwagevar($minwage) ///
                        fes($did_base) ///
                        weightvar(weight) ///
                        clustervar($clustervar) ///
                        qcvar(qc_ct)
            }

            ** Add table statistics
            add_table_stats, outcome(`out') treatvar(treated) ///
                postvar(post) statevar(ca) qcvar(qc_present) weightvar(weight)

            ** Add population indicator
            estadd local pop_`pop_ct' "\checkmark"

            local pop_ct = `pop_ct' + 1

        }

        ** Define statistics labels
        local stats_labels `" "  Observations" "  Adj. R-Square" "  Treated group mean in pre-period" "'

        ** Export table using utility
        export_results est_`out'_sw est_`out'_sm est_`out'_mw est_`out'_mm, ///
            filename("tab_otherpops_`spec_lbl'_`ct'.tex") ///
            statslist("N r2_a ymean") ///
            statsfmt("%9.0fc %9.3fc %9.1fc") ///
            statslabels(`stats_labels')

        ** For first outcome, create population indicators table
        if `ct' == 1 {
            local pop_labels `" "  Single Women" "  Single Men" "  Married Women" "  Married Men" "'

            export_results est_`out'_sw est_`out'_sm est_`out'_mw est_`out'_mm, ///
                filename("tab_otherpops_`spec_lbl'_end.tex") ///
                statslist("pop_1 pop_2 pop_3 pop_4") ///
                statsfmt("%9s %9s %9s %9s") ///
                statslabels(`pop_labels') ///
                cellsnone
        }

        ** Update count
        local ct = `ct' + 1

    }

}

** =============================================================================
** PART 2: EVENT STUDY FIGURES BY POPULATION
** =============================================================================

dis ""
dis "=============================================="
dis "Running event study figures by population"
dis "=============================================="

** Loop over populations
foreach pop of local pops {

    ** Get population conditions
    local fem_val = `pop_`pop'_fem'
    local mar_val = `pop_`pop'_mar'
    local pop_name "`pop_`pop'_name'"

    dis ""
    dis "Population: `pop_name'"
    dis "----------------------------------------------"

    ** Clear stored estimates
    eststo clear

    ** Load ACS data with sample restrictions
    use weight $outcomes $controls $unemp $minwage qc_* year ///
        female married in_school age_sample_20_49 citizen_test state_fips state_status ///
        if  female == `fem_val' & ///
            married == `mar_val' & ///
            in_school == 0 & ///
            age_sample_20_49 == 1 & ///
            citizen_test == 1 & ///
            education < 4 & ///
            state_status > 0 & ///
            inrange(year, ${start_year}, ${end_year}) ///
        using "${data}final/acs_working_file.dta", clear

    ** Create DID variables including event study variable
    setup_did_vars, eventstudy

    ** Loop over outcome variables
    foreach out of global outcomes {

        ** Scale outcome to percentage points
        replace `out' = `out' * 100

        ** Run event-study regression (spec 4: all controls)
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

    ** Create coefficient plot
    make_event_plot est_employed_y est_full_time_y est_part_time_y, ///
        eventvar(childXyearXca) ///
        startyear(${start_year}) ///
        endyear(${end_year}) ///
        baseyear(2014) ///
        ymax(6) ///
        ycut(2) ///
        savepath("${results}figures/fig_event_emp_`pop'.jpg") ///
        labels(Employed|Employed full-time|Employed part-time)

    ** Export graph using utility
    export_graph, filename("fig_event_emp_`pop'")

    ** Export coefficients for reference
    export_event_coefficients est_employed_y est_full_time_y est_part_time_y, ///
        eventvar(childXyearXca) ///
        startyear(${start_year}) ///
        endyear(${end_year}) ///
        baseyear(2014) ///
        outfile("${results}tables/fig_event_emp_`pop'_coefficients.csv")

}

** =============================================================================
** End
** =============================================================================

clear
log close log_04_appendix_otherpops
