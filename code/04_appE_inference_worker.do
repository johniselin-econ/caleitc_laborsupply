/*******************************************************************************
File Name:      04_appE_inference_worker.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Standalone worker do-file for inference estimation
                Can be called directly with task_id argument for debugging
                or as fallback when parallel package has issues.

Usage:          do 04_appE_inference_worker.do, args(task_id)
                Example: do 04_appE_inference_worker.do, args(1)

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** =============================================================================
** Get task assignment
** =============================================================================

** Check if task_id was passed as argument
args my_task

** Validate task_id
if missing("`my_task'") {
    di as error "Error: task_id argument required"
    di as error "Usage: do 04_appE_inference_worker.do, args(task_id)"
    di as error "       where task_id is 1-8"
    exit 198
}

if !inrange(`my_task', 1, 8) {
    di as error "Error: task_id must be between 1 and 8"
    exit 198
}

** Load task list to get parameters
use "${data}interim/inference_tasks.dta", clear
keep if task_id == `my_task'

** Extract task parameters
local out = outcome[1]
local spec = spec[1]

di _n "Worker: Processing task `my_task' (outcome=`out', spec=`spec')"

** =============================================================================
** Load prepared data
** =============================================================================

use "${data}interim/acs_prepared_for_inference.dta", clear

** Get bootstrap parameters from globals (or use defaults)
if missing("$par_B") {
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
}
else {
    local B = $par_B
    local B_ri = $par_B_ri
    local debug_text "$par_debug_text"
}

** =============================================================================
** Define specifications
** =============================================================================

** SPEC 1: Basic triple-diff
local did1 "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"
local unemp1 ""
local controls1 ""

** SPEC 2: Add demographic controls
local did2 "`did1'"
local unemp2 ""
local controls2 "education age_bracket minage_qc race_group hispanic hh_adult_ct"

** SPEC 3: Add unemployment controls
local did3 "`did1'"
local unemp3 "c.state_unemp#i.qc_ct"
local controls3 "`controls2'"

** SPEC 4: Add minimum wage controls
local did4 "`did1'"
local unemp4 "`unemp3' c.minwage#i.qc_ct"
local controls4 "`controls2'"

** For wild cluster bootstrap (areg variant)
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

** =============================================================================
** Run inference for this task
** =============================================================================

** Set specification locals
local did "`did`spec''"
local unemp "`unemp`spec''"
local controls "`controls`spec''"

local absorb "`absorb`spec'_areg'"
local did_areg "`did`spec'_areg'"
local controls_areg "`controls`spec'_areg'"

di _n "Running inference for `out', specification `spec'"

** -----------------------------------------------------------------------------
** Wild Cluster Bootstrap
** -----------------------------------------------------------------------------
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

** -----------------------------------------------------------------------------
** Randomization Inference Wild Bootstrap (parallelized version)
** -----------------------------------------------------------------------------
di "  - Randomization Inference Wild Bootstrap..."

ri_bs_par `out' treated "`did'" "`controls'" "`unemp'" ///
    state_fips weight `B_ri' pot_treat ///
    "${data}interim/data_`out'_`spec'_riwcbs`debug_text'.dta"

local p_riwcbs_b = `r(p_beta)'
local p_riwcbs_t = `r(p_t)'

** -----------------------------------------------------------------------------
** Block Bootstrap (Ferman-Pinto, parallelized version)
** -----------------------------------------------------------------------------
di "  - Ferman-Pinto Block Bootstrap..."

ferman_pinto_boot_ind_par `out' treated "`did'" "`controls'" "`unemp'" ///
    state_fips year qc_present weight `B' ///
    "${data}interim/data_`out'_`spec'_fp2019`debug_text'.dta"

local p_block_fp = `r(p_with)'
local p_block = `r(p_without)'

** -----------------------------------------------------------------------------
** Main regression with CRVE
** -----------------------------------------------------------------------------
di "  - CRVE regression..."

reghdfe `out' treated `unemp' [aw = weight], ///
    absorb(`did' `controls') ///
    vce(cluster state_fips)

** Calculate CRVE p-value
local beta = _b[treated]
local se = _se[treated]
local t = `beta' / `se'
local p_crve = 2 * ttail(e(df_r), abs(`t'))
local N = e(N)

** =============================================================================
** Save results for this task
** =============================================================================

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

di _n "Task `my_task' complete. Results saved to: ${data}interim/inference_results_task`my_task'.dta"
