/*******************************************************************************
File Name:      04_appE_inference_parallel.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix E alternative inference procedures
                PARALLELIZED VERSION using Stata's parallel package

                Calculates p-values using:
                - Cluster-robust variance estimator (CRVE)
                - Wild cluster bootstrap (WCB)
                - Randomization inference wild bootstrap (RIWB)
                - Block bootstrap with Ferman-Pinto (2019) correction

                References:
                - Ferman and Pinto (2019): Inference in Differences-in-Differences
                  with Few Treated Groups and Heteroskedasticity
                - MacKinnon and Webb (2019): Wild Bootstrap Inference for
                  Wildly Different Cluster Sizes

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appE_inference
log using "${logs}04_appE_inference_log_${date}", ///
    name(log_04_appE_inference) replace text

** =============================================================================
** Setup parallel processing
** =============================================================================

** Install parallel package if not already installed
capture which parallel
if _rc {
    ssc install parallel, replace
}

** Set number of clusters (adjust based on your machine)
** Use fewer clusters than physical cores to avoid memory issues
if missing("${ncores}") {
    local ncores = 4
}
else {
    local ncores = ${ncores}
}

parallel setclusters `ncores', force

** Display parallel setup
di _n "Parallel processing enabled with `ncores' clusters"

** =============================================================================
** Define parameters
** =============================================================================

** Sample period
local start = 2012
local end = 2017

** Define outcomes
local outcomes "full_time_y part_time_y"

** Bootstrap parameters (adjust for debug mode)
if ${debug} == 1 {
    local B = 10
    local B_ri = 4
    local debug_text "_debug"
}
else {
    local B = 1000
    local B_ri = 100
    local debug_text ""
}

** Store parameters in globals for worker access
global par_B = `B'
global par_B_ri = `B_ri'
global par_debug_text "`debug_text'"
global par_start = `start'
global par_end = `end'

** =============================================================================
** Load data and prepare sample (do once, save for workers)
** =============================================================================

use if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        state_status > 0 & ///
        education <= 3 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", replace

** Rescale outcome variables to percentage points
foreach out of local outcomes {
    replace `out' = `out' * 100
}

** Create main DID variables
gen ca = (state_fips == 6)
gen childXyearXca = cond(qc_present == 1 & ca == 1, year, 2014)
gen treated = (state_fips == 6 & qc_present == 1 & year >= 2015)
gen post = (year >= 2015)
label var treated "ATE"

** Update adults per HH (cap at 3)
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** Generate minimum wage variable
gen minwage = mean_st_mw
label var minwage "Binding state minimum wage"

** For wild cluster bootstrap (areg variant)
egen grp_state_year = group(state_fips year)
egen grp_state_qc = group(state_fips qc_ct)
egen grp_year_qc = group(year qc_ct)

** For randomization inference
gen pot_treat = (qc_present == 1) & (year >= 2015)

** Save prepared data for parallel workers
save "${data}interim/acs_prepared_for_inference.dta", replace

** =============================================================================
** Create task list for parallel processing
** =============================================================================

** Generate all outcome × specification combinations
clear
set obs 8

gen task_id = _n
gen outcome = ""
gen spec = .

** Assign tasks
replace outcome = "full_time_y" if inrange(task_id, 1, 4)
replace outcome = "part_time_y" if inrange(task_id, 5, 8)
replace spec = mod(task_id - 1, 4) + 1

** Save task list
save "${data}interim/inference_tasks.dta", replace

** Display task assignments
list, clean

** =============================================================================
** Run parallel inference
** =============================================================================

di _n "Starting parallel inference estimation..."
di "Tasks: 8 (2 outcomes × 4 specifications)"
di "Bootstrap replications: $par_B"
di "RI bootstrap replications: $par_B_ri"

** The parallel package requires running a program on the data in memory.
** We'll define a wrapper program that processes each task.

capture program drop run_inference_task
program define run_inference_task
    ** This program runs on the task list dataset split by parallel
    ** Each worker gets a subset of rows (tasks)

    ** Get task parameters from the current observation
    local my_task = task_id[1]
    local out = outcome[1]
    local spec = spec[1]

    di _n "Running task `my_task': outcome=`out', spec=`spec'"

    ** Load the prepared analysis data
    use "${data}interim/acs_prepared_for_inference.dta", clear

    ** Get bootstrap parameters
    local B = $par_B
    local B_ri = $par_B_ri
    local debug_text "$par_debug_text"

    ** Define specifications
    local did1 "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"
    local unemp1 ""
    local controls1 ""

    local did2 "`did1'"
    local unemp2 ""
    local controls2 "education age_bracket minage_qc race_group hispanic hh_adult_ct"

    local did3 "`did1'"
    local unemp3 "c.state_unemp#i.qc_ct"
    local controls3 "`controls2'"

    local did4 "`did1'"
    local unemp4 "`unemp3' c.minwage#i.qc_ct"
    local controls4 "`controls2'"

    local absorb1_areg "grp_state_year"
    local did1_areg "i.state_fips i.qc_ct i.year i.grp_state_qc i.grp_year_qc"
    local controls1_areg ""

    local absorb2_areg "`absorb1_areg'"
    local did2_areg "`did1_areg'"
    local controls2_areg "i.education i.age_bracket i.minage_qc i.race_group i.hispanic i.hh_adult_ct"

    local absorb3_areg "`absorb1_areg'"
    local did3_areg "`did1_areg'"
    local controls3_areg "`controls2_areg'"

    local absorb4_areg "`absorb1_areg'"
    local did4_areg "`did1_areg'"
    local controls4_areg "`controls2_areg'"

    ** Set locals for this specification
    local did "`did`spec''"
    local unemp "`unemp`spec''"
    local controls "`controls`spec''"
    local absorb "`absorb`spec'_areg'"
    local did_areg "`did`spec'_areg'"
    local controls_areg "`controls`spec'_areg'"

    ** -------------------------------------------------------------------------
    ** Wild Cluster Bootstrap
    ** -------------------------------------------------------------------------
    di "  - Wild Cluster Bootstrap..."

    wildbootstrap ///
        areg `out' treated `unemp' `did_areg' `controls_areg' ///
        [aw = weight], ///
        absorb(`absorb') ///
        cluster(state_fips) ///
        coefficients(treated) ///
        reps(`B') ///
        rseed(${seed})

    local p_wcbs = e(wboot)[1,3]

    ** -------------------------------------------------------------------------
    ** Randomization Inference Wild Bootstrap
    ** -------------------------------------------------------------------------
    di "  - Randomization Inference Wild Bootstrap..."

    ri_bs_par `out' treated "`did'" "`controls'" "`unemp'" ///
        state_fips weight `B_ri' pot_treat ///
        "${data}interim/data_`out'_`spec'_riwcbs`debug_text'.dta"

    local p_riwcbs_b = `r(p_beta)'
    local p_riwcbs_t = `r(p_t)'

    ** -------------------------------------------------------------------------
    ** Ferman-Pinto Block Bootstrap
    ** -------------------------------------------------------------------------
    di "  - Ferman-Pinto Block Bootstrap..."

    ferman_pinto_boot_ind_par `out' treated "`did'" "`controls'" "`unemp'" ///
        state_fips year qc_present weight `B' ///
        "${data}interim/data_`out'_`spec'_fp2019`debug_text'.dta"

    local p_block_fp = `r(p_with)'
    local p_block = `r(p_without)'

    ** -------------------------------------------------------------------------
    ** CRVE Regression
    ** -------------------------------------------------------------------------
    di "  - CRVE regression..."

    reghdfe `out' treated `unemp' [aw = weight], ///
        absorb(`did' `controls') ///
        vce(cluster state_fips)

    local beta = _b[treated]
    local se = _se[treated]
    local t = `beta' / `se'
    local p_crve = 2 * ttail(e(df_r), abs(`t'))
    local N = e(N)

    ** -------------------------------------------------------------------------
    ** Save results
    ** -------------------------------------------------------------------------
    clear
    set obs 1

    gen task_id = `my_task'
    gen outcome = "`out'"
    gen spec = `spec'
    gen beta = `beta'
    gen se = `se'
    gen N = `N'
    gen p_crve = `p_crve'
    gen p_wcbs = `p_wcbs'
    gen p_riwcbs_b = `p_riwcbs_b'
    gen p_riwcbs_t = `p_riwcbs_t'
    gen p_block = `p_block'
    gen p_block_fp = `p_block_fp'

    save "${data}interim/inference_results_task`my_task'.dta", replace

    di _n "Task `my_task' complete."
end

** Load task list for parallel processing
use "${data}interim/inference_tasks.dta", clear
sort task_id

** Run tasks in parallel - each worker processes one task_id
parallel, by(task_id) prog(ferman_pinto_boot_ind_par ri_bs_par run_inference_task): ///
    run_inference_task

** =============================================================================
** Combine results from parallel runs
** =============================================================================

di _n "Combining results from parallel workers..."

** Load and append all results
clear
local first = 1

forvalues t = 1/8 {
    capture confirm file "${data}interim/inference_results_task`t'.dta"
    if _rc == 0 {
        if `first' == 1 {
            use "${data}interim/inference_results_task`t'.dta", clear
            local first = 0
        }
        else {
            append using "${data}interim/inference_results_task`t'.dta"
        }
    }
    else {
        di as error "Warning: Results file for task `t' not found"
    }
}

** Save combined results
save "${data}interim/inference_results_combined`debug_text'.dta", replace

** =============================================================================
** Generate output tables
** =============================================================================

** Reload prepared data for eststo
use "${data}interim/acs_prepared_for_inference.dta", clear

** Define specifications for table generation
local did1 "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"
local unemp1 ""
local controls1 ""

local did2 "`did1'"
local unemp2 ""
local controls2 "education age_bracket minage_qc race_group hispanic hh_adult_ct"

local did3 "`did1'"
local unemp3 "c.state_unemp#i.qc_ct"
local controls3 "`controls2'"

local did4 "`did1'"
local unemp4 "`unemp3' c.minwage#i.qc_ct"
local controls4 "`controls2'"

** Load combined results
preserve
use "${data}interim/inference_results_combined`debug_text'.dta", clear
tempfile results
save `results'
restore

** Generate tables for each outcome
local i = 1
foreach out in full_time_y part_time_y {

    di _n "Generating table for outcome: `out'"

    forvalues spec = 1/4 {

        ** Run main regression for eststo
        local did "`did`spec''"
        local unemp "`unemp`spec''"
        local controls "`controls`spec''"

        eststo `out'_`spec': ///
            reghdfe `out' treated `unemp' [aw = weight], ///
            absorb(`did' `controls') ///
            vce(cluster state_fips)

        ** Get p-values from combined results
        preserve
        use `results', clear
        keep if outcome == "`out'" & spec == `spec'

        local p_crve = p_crve[1]
        local p_wcbs = p_wcbs[1]
        local p_riwcbs_b = p_riwcbs_b[1]
        local p_riwcbs_t = p_riwcbs_t[1]
        local p_block = p_block[1]
        local p_block_fp = p_block_fp[1]

        restore

        ** Add p-values to estimates
        estadd scalar p_crve = `p_crve'
        estadd scalar p_wcbs = `p_wcbs'
        estadd scalar p_riwcbs_b = `p_riwcbs_b'
        estadd scalar p_riwcbs_t = `p_riwcbs_t'
        estadd scalar p_block = `p_block'
        estadd scalar p_block_fp = `p_block_fp'
    }

    ** Export results table
    local stats_list "N p_crve p_wcbs p_riwcbs_b p_riwcbs_t p_block p_block_fp"
    local stats_fmt "%9.0fc %9.3fc %9.3fc %9.3fc %9.3fc %9.3fc %9.3fc"

    local stats_labels `" "  Observations" "'
    local stats_labels `" `stats_labels' "  CRVE P-Value" "'
    local stats_labels `" `stats_labels' "  WCBS P-Value" "'
    local stats_labels `" `stats_labels' "  RIWB-t P-Value" "'
    local stats_labels `" `stats_labels' "  RIWB-b P-Value" "'
    local stats_labels `" `stats_labels' "  BB P-Value" "'
    local stats_labels `" `stats_labels' "  Corrected BB P-Value" "'

    ** Export to local results
    esttab `out'_* using ///
        "${results}tables/tab_appE_tab1_`i'`debug_text'.tex", ///
        booktabs fragment nobaselevels replace nomtitles nonumbers ///
        stats(`stats_list', ///
            fmt("`stats_fmt'") labels(`stats_labels')) ///
        b(1) se(1) label order(treated) keep(treated) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        prehead("\\ \midrule") nolines

    ** Export to Overleaf
    if ${overleaf} == 1 {
        esttab `out'_* using ///
            "${ol_tab}tab_appE_tab1_`i'`debug_text'.tex", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers ///
            stats(`stats_list', ///
                fmt("`stats_fmt'") labels(`stats_labels')) ///
            b(1) se(1) label order(treated) keep(treated) ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("\\ \midrule") nolines
    }

    local i = `i' + 1
}

** =============================================================================
** Cleanup temporary files
** =============================================================================

** Remove task-specific result files
forvalues t = 1/8 {
    capture erase "${data}interim/inference_results_task`t'.dta"
}

** Keep combined results and prepared data for reference
di _n "Parallel inference complete."
di "Combined results saved to: ${data}interim/inference_results_combined`debug_text'.dta"

** =============================================================================
** End
** =============================================================================

clear
log close log_04_appE_inference
