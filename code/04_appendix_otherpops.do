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

                Uses utility programs: run_triple_diff, add_spec_indicators,
                add_table_stats, run_event_study, make_event_plot

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appendix_otherpops
log using "${logs}04_appendix_otherpops_log_${date}", name(log_04_appendix_otherpops) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define outcome variables
local outcomes "employed_y full_time_y part_time_y"

** Define control variables
local controls "education age_bracket minage_qc race_group hispanic hh_adult_ct"

** Define unemployment control variable
local unemp "state_unemp"

** Define minimum wage control variable
local minwage "mean_st_mw"

** Define cluster variable
local clustervar "state_fips"

** Define start and end dates
local start = ${start_year}
local end = ${end_year}

** Base fixed effects
local did_base "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"

** Define populations
local pops "sw sm mw mm"
local pop_labels `" "Single Women" "Single Men" "Married Women" "Married Men" "'

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
    foreach out of local outcomes {

        dis ""
        dis "Outcome: `out'"
        dis "----------------------------------------------"

        ** Loop over populations
        local pop_ct = 1
        foreach pop of local pops {

            ** Set sample restrictions based on population
            if "`pop'" == "sw" {
                local fem_cond "female == 1"
                local mar_cond "married == 0"
                local pop_name "Single Women"
            }
            else if "`pop'" == "sm" {
                local fem_cond "female == 0"
                local mar_cond "married == 0"
                local pop_name "Single Men"
            }
            else if "`pop'" == "mw" {
                local fem_cond "female == 1"
                local mar_cond "married == 1"
                local pop_name "Married Women"
            }
            else if "`pop'" == "mm" {
                local fem_cond "female == 0"
                local mar_cond "married == 1"
                local pop_name "Married Men"
            }

            dis "  Population: `pop_name'"

            ** Load ACS data with sample restrictions
            use weight `outcomes' `controls' `unemp' `minwage' qc_* year ///
                female married in_school age citizen_test state_fips state_status ///
                if  `fem_cond' & ///
                    `mar_cond' & ///
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
            label var treated "`pop_name'"

            ** Update adults per HH (cap at 3)
            replace hh_adult_ct = 3 if hh_adult_ct > 3

            ** Scale outcome to percentage points
            replace `out' = `out' * 100

            ** Run regression based on specification
            if `spec' == 1 {
                ** SPEC 1: Basic triple-diff FEs only
                eststo est_`out'_`pop': ///
                    run_triple_diff `out', ///
                        treatvar(treated) ///
                        fes(`did_base') ///
                        weightvar(weight) ///
                        clustervar(`clustervar')
            }
            else {
                ** SPEC 4: All covariates
                eststo est_`out'_`pop': ///
                    run_triple_diff `out', ///
                        treatvar(treated) ///
                        controls(`controls') ///
                        unempvar(`unemp') ///
                        minwagevar(`minwage') ///
                        fes(`did_base') ///
                        weightvar(weight) ///
                        clustervar(`clustervar') ///
                        qcvar(qc_ct)
            }

            ** Add table statistics
            add_table_stats, outcome(`out') treatvar(treated) ///
                postvar(post) statevar(ca) qcvar(qc_present) weightvar(weight)

            ** Add population indicator
            estadd local pop_`pop_ct' "\checkmark"

            local pop_ct = `pop_ct' + 1

        }

        ** Export table for this outcome
        local stats_list "N r2_a ymean"
        local stats_fmt "%9.0fc %9.3fc %9.1fc"

        ** Define statistics labels
        local stats_labels `" "  Observations" "'
        local stats_labels `" `stats_labels' "  Adj. R-Square" "'
        local stats_labels `" `stats_labels' "  Treated group mean in pre-period" "'

        ** Save table locally
        esttab est_`out'_sw est_`out'_sm est_`out'_mw est_`out'_mm using ///
            "${results}tables/tab_otherpops_`spec_lbl'_`ct'.tex", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
            stats(`stats_list', ///
                    fmt("`stats_fmt'") ///
                    labels(`stats_labels')) ///
            b(1) se(1) label order(treated) keep(treated) ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("\\ \midrule")

        ** Save to overleaf if enabled
        if ${overleaf} == 1 {
            esttab est_`out'_sw est_`out'_sm est_`out'_mw est_`out'_mm using ///
                "${ol_tab}tab_otherpops_`spec_lbl'_`ct'.tex", ///
                booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
                stats(`stats_list', ///
                        fmt("`stats_fmt'") ///
                        labels(`stats_labels')) ///
                b(1) se(1) label order(treated) keep(treated) ///
                star(* 0.10 ** 0.05 *** 0.01) ///
                prehead("\\ \midrule")
        }

        ** For first outcome, create population indicators table
        if `ct' == 1 {

            ** Define statistics to be included (indicators for populations)
            local stats_list "pop_1 pop_2 pop_3 pop_4"

            ** Define statistics formats
            local stats_fmt "%9s %9s %9s %9s"

            ** Define statistics labels
            local stats_labels `" "  Single Women" "'
            local stats_labels `" `stats_labels' "  Single Men" "'
            local stats_labels `" `stats_labels' "  Married Women" "'
            local stats_labels `" `stats_labels' "  Married Men" "'

            ** Save
            esttab est_`out'_sw est_`out'_sm est_`out'_mw est_`out'_mm using ///
                "${results}tables/tab_otherpops_`spec_lbl'_end.tex", ///
                booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
                stats(`stats_list', ///
                    fmt("`stats_fmt'") ///
                    labels(`stats_labels')) ///
                cells(none) prehead("\\ \midrule")

            if ${overleaf} == 1 {
                esttab est_`out'_sw est_`out'_sm est_`out'_mw est_`out'_mm using ///
                    "${ol_tab}tab_otherpops_`spec_lbl'_end.tex", ///
                    booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
                    stats(`stats_list', ///
                        fmt("`stats_fmt'") ///
                        labels(`stats_labels')) ///
                    cells(none) prehead("\\ \midrule")
            }
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

** Fixed effects for event study
local did "qc_ct year state_fips"
local did "`did' state_fips#year"
local did "`did' state_fips#qc_ct"
local did "`did' year#qc_ct"

** Loop over populations
foreach pop of local pops {

    ** Set sample restrictions based on population
    if "`pop'" == "sw" {
        local fem_cond "female == 1"
        local mar_cond "married == 0"
        local pop_name "Single Women"
        local pop_title "Single Women"
    }
    else if "`pop'" == "sm" {
        local fem_cond "female == 0"
        local mar_cond "married == 0"
        local pop_name "Single Men"
        local pop_title "Single Men"
    }
    else if "`pop'" == "mw" {
        local fem_cond "female == 1"
        local mar_cond "married == 1"
        local pop_name "Married Women"
        local pop_title "Married Women"
    }
    else if "`pop'" == "mm" {
        local fem_cond "female == 0"
        local mar_cond "married == 1"
        local pop_name "Married Men"
        local pop_title "Married Men"
    }

    dis ""
    dis "Population: `pop_name'"
    dis "----------------------------------------------"

    ** Clear stored estimates
    eststo clear

    ** Load ACS data with sample restrictions
    use weight `outcomes' `controls' `unemp' `minwage' qc_* year ///
        female married in_school age citizen_test state_fips state_status ///
        if  `fem_cond' & ///
            `mar_cond' & ///
            in_school == 0 & ///
            age_sample_20_49 == 1 & ///
            citizen_test == 1 & ///
            education < 4 & ///
            state_status > 0 & ///
            inrange(year, `start', `end') ///
        using "${data}final/acs_working_file.dta", clear

    ** Create event-study interaction variable
    gen ca = (state_fips == 6)
    gen childXyearXca = cond(qc_present == 1 & ca == 1, year, 2014)

    ** Update adults per HH (cap at 3)
    replace hh_adult_ct = 3 if hh_adult_ct > 3
    label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
    label values hh_adult_ct lb_adult_ct

    ** Loop over outcome variables
    foreach out of local outcomes {

        ** Scale outcome to percentage points
        replace `out' = `out' * 100

        ** Run event-study regression (spec 4: all controls)
        eststo est_`out': ///
            run_event_study `out', ///
                eventvar(childXyearXca) ///
                baseyear(2014) ///
                controls(`controls') ///
                unempvar(`unemp') ///
                minwagevar(`minwage') ///
                fes(`did') ///
                weightvar(weight) ///
                clustervar(`clustervar') ///
                qcvar(qc_ct)

    }

    ** Create coefficient plot
    make_event_plot est_employed_y est_full_time_y est_part_time_y, ///
        eventvar(childXyearXca) ///
        startyear(`start') ///
        endyear(`end') ///
        baseyear(2014) ///
        ymax(6) ///
        ycut(2) ///
        savepath("${results}figures/fig_event_emp_`pop'.jpg") ///
        labels(Employed|Employed full-time|Employed part-time) 

    ** Also save as PNG
    graph export "${results}figures/fig_event_emp_`pop'.png", ///
        as(png) name("Graph") width(2400) height(1600) replace

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        graph export "${ol_fig}fig_event_emp_`pop'.jpg", as(jpg) quality(100) replace
    }

    ** Export coefficients for reference
    preserve
        clear
        gen outcome = ""
        gen year = .
        gen coef = .
        gen se = .
        gen ci_lo = .
        gen ci_hi = .

        local row = 1
        foreach out in employed_y full_time_y part_time_y {
            forvalues y = `start'(1)`end' {
                if `y' != 2014 {
                    qui est restore est_`out'
                    local b = _b[`y'.childXyearXca]
                    local s = _se[`y'.childXyearXca]

                    set obs `row'
                    qui replace outcome = "`out'" in `row'
                    qui replace year = `y' in `row'
                    qui replace coef = `b' in `row'
                    qui replace se = `s' in `row'
                    qui replace ci_lo = `b' - 1.96 * `s' in `row'
                    qui replace ci_hi = `b' + 1.96 * `s' in `row'

                    local row = `row' + 1
                }
            }
        }

        export delimited "${results}tables/fig_event_emp_`pop'_coefficients.csv", replace
    restore

}

** =============================================================================
** End
** =============================================================================

clear
log close log_04_appendix_otherpops
