/*******************************************************************************
Phase 3 — Stage 11: deterministic golden dumps for the inference-battery port
Run as a 12-task SLURM array (stage11_inference_dump.sbatch); task_id maps to
(outcome, spec) exactly as the battery's serial task counter:
employed_y 1-4, full_time_y 5-8, part_time_y 9-12.

For each task, dumps the DETERMINISTIC layers of the corrected Appendix E
programs (04_appE_inference.do / _programs.do) — no resampling:
  - data/tmp/appE_det_ri_task<k>.dta:  j, state_fips, b, t for the actual
    fit (j = 0, CA) and every placebo refit (j = 1..n, dense rank of sorted
    non-CA fips; identical design, CA kept in sample)
  - data/tmp/appE_det_fp_task<k>.dta:  Ferman-Pinto state-level table
    (ca, W_did, q, P_qjt, var_M, W_normalized) + alpha_hat, using the
    PARALLEL program's finite-sample-correction semantics (the golden run)

The R port (code/R/utils/inference.R) must reproduce these exactly
(code/R/validate/validate_inference_det.R). Resampling p-values are instead
checked against the job-17058169 golden tables within Monte-Carlo bands.
*******************************************************************************/

capture log close _all
clear matrix
clear all
set more off

global pr_name "caleitc"
global date "`: di %tdCY-N-D daily("$S_DATE", "DMY")'"

global dir      "`c(pwd)'/"
global dir : subinstr global dir "\" "/" , all
global code     "${dir}code/"
global data     "${dir}data/"
global results  "${dir}results/"
global logs     "${code}logs/"

cd ${dir}

global seed 56403
global start_year = 2012
global end_year = 2017

local task : env SLURM_ARRAY_TASK_ID
if "`task'" == "" local task = 1

log using "${logs}phase3_stage11_task`task'_${date}", replace text

cap mkdir "${data}tmp"

** Map task -> (outcome, spec)
local outcomes "employed_y full_time_y part_time_y"
local oi = ceil(`task' / 4)
local spec = `task' - (`oi' - 1) * 4
local out : word `oi' of `outcomes'
dis "Task `task': outcome `out', spec `spec'"

** =============================================================================
** Load data and prepare sample (04_appE_inference.do:442-471, verbatim)
** =============================================================================

use if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        state_status > 0 & ///
        education < 4 & ///
        inrange(year, ${start_year}, ${end_year}) ///
    using "${data}final/acs_working_file.dta", clear

foreach o of local outcomes {
    replace `o' = `o' * 100
}

gen ca = (state_fips == 6)
gen treated = (state_fips == 6 & qc_present == 1 & year >= 2015)
gen post = (year >= 2015)

replace hh_adult_ct = 3 if hh_adult_ct > 3

gen minwage = mean_st_mw

gen pot_treat = (qc_present == 1) & (year >= 2015)

** Specifications (04_appE_inference.do:477-495)
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

local did "`did`spec''"
local unemp "`unemp`spec''"
local controls "`controls`spec''"

** =============================================================================
** (a) Actual fit (j = 0) and RI placebo refits (deterministic)
** =============================================================================

reghdfe `out' treated `unemp' [aw = weight], ///
    vce(cluster state_fips) absorb(`did' `controls')
local alpha_hat = _b[treated]
local t_hat_0 = _b[treated] / _se[treated]

egen control_states = group(state_fips) if state_fips != 6
qui summ control_states
local n = r(max)
dis "Placebo states: `n'"

** j -> fips mapping
tempfile jmap
preserve
keep state_fips control_states
duplicates drop
drop if missing(control_states)
rename control_states j
save `jmap'
restore

tempfile ri_raw
postfile ri_post j b t using `ri_raw', replace
post ri_post (0) (`alpha_hat') (`t_hat_0')

forvalues j = 1/`n' {
    gen ptreat = (control_states == `j') & (pot_treat == 1)
    qui reghdfe `out' ptreat `unemp' [aw = weight], ///
        vce(cluster state_fips) absorb(`did' `controls')
    post ri_post (`j') (_b[ptreat]) (_b[ptreat] / _se[ptreat])
    drop ptreat
}
postclose ri_post

preserve
use `ri_raw', clear
merge 1:1 j using `jmap', keep(master match) nogen
replace state_fips = 6 if j == 0
sort j
save "${data}tmp/appE_det_ri_task`task'.dta", replace
restore

** =============================================================================
** (b) Ferman-Pinto deterministic prep (programs.do:29-108, parallel variant)
** =============================================================================

preserve

reghdfe `out' `unemp' [aw = weight], vce(cluster state_fips) ///
    absorb(`did' `controls', savefe) resid
qui predict eta_iqjt, resid

keep year state_fips weight eta_iqjt qc_present ca post

bysort state_fips year qc_present: egen P_qjt = total(weight)

gen tmp_eta_iqjt = eta_iqjt * (weight / P_qjt)
bysort state_fips year qc_present: egen eta_qjt = total(tmp_eta_iqjt)

gen temp = .
forvalues p = 0/1 {
    forvalues q = 0/1 {
        qui egen P_q1`p' = total(weight) if ca == 1 & post == `p' & qc_present == `q'
        qui replace temp = (P_qjt / P_q1`p') if ca == 1 & post == `p' & qc_present == `q'
        drop P_q1`p'
    }
}

egen Pr_q1t = mean(temp), by(year qc_present)
drop temp

gen W_did = .
qui replace W_did = Pr_q1t * eta_qjt if post == 1 & qc_present == 1
qui replace W_did = -Pr_q1t * eta_qjt if post == 1 & qc_present == 0
qui replace W_did = -Pr_q1t * eta_qjt if post == 0 & qc_present == 1
qui replace W_did = Pr_q1t * eta_qjt if post == 0 & qc_present == 0

gen tmp = weight^2
bysort state_fips year qc_present: egen omega2 = sum(tmp)
gen q = (Pr_q1t^2) * omega2 / (P_qjt^2)

keep state_fips year qc_present ca W_did q P_qjt
duplicates drop state_fips year qc_present ca W_did q P_qjt, force
collapse (mean) ca (sum) W_did q P_qjt, by(state_fips)

qui summ W_did [aw = P_qjt], detail
local mean = r(mean)
gen W2 = (W_did - `mean')^2

reg W2 q [pw = P_qjt]
predict var_M

local beta_q = _b[q]
local const = _b[_cons]

summ var_M
local min = r(min)

** Parallel-program correction semantics (04_appE_inference_programs.do:104-105)
qui replace var_M = 1 if `min' < 0 & `beta_q' < 0
qui replace var_M = q if `min' < 0 & `const' < 0

gen W_normalized = W_did / sqrt(var_M)
gen alpha_hat = `alpha_hat'

drop W2
sort state_fips
save "${data}tmp/appE_det_fp_task`task'.dta", replace

restore

dis "STAGE 11 TASK `task' COMPLETE"
log close _all
