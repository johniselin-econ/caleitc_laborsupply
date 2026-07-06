/*******************************************************************************
Phase 3 — Stage 10: regenerate the SDID county panel (golden file)
Run from repo root: stata-mp -b do code/hpc/stage10_sdid_panel.do

Replicates the panel-build section of 03_sdid_county.do (lines 78-222)
verbatim against the rebuilt working file and saves
data/interim/sdid_county_panel.dta. The sdid_wt estimation loop is NOT run —
Table 2 is being re-estimated on the synthdid_weights fork (PLAN.md §D).
The R port (code/R/utils/sdid_panel.R) must reproduce this panel
row-for-row (see code/R/validate/validate_sdid_panel.R).
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

global end_year = 2017

log using "${logs}phase3_stage10_sdid_panel_${date}", replace text

** =============================================================================
** Setup (03_sdid_county.do:40-48)
** =============================================================================

local outcomes "employed_y full_time_y part_time_y incearn_real"
local start = 2010
local end = ${end_year}
local num_years = `end' - `start' + 1

** =============================================================================
** Load and Prepare Data (03_sdid_county.do:78-116, verbatim)
** =============================================================================

use weight `outcomes' state_unemp county_unemp mean_st_mw qc_* year ///
    female married in_school age_sample_20_49 citizen_test state_fips county_fips state_status ///
    race_group hispanic education age_bracket ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", clear

gen unemp = county_unemp
replace unemp = state_unemp if missing(unemp)
gen minwage = mean_st_mw

local controls "unemp minwage"

foreach out in employed_y full_time_y part_time_y {
    replace `out' = 100 * `out'
}

gen n = 1

keep year state_fips county_fips `outcomes' `controls' weight qc_present n

** =============================================================================
** Handle Unbalanced Panel - Group Small Counties (03_sdid_county.do:118-136)
** =============================================================================

bysort state_fips county_fips qc_present year: gen ct = _n
gen first = (ct == 1)
drop ct

bysort state_fips county_fips qc_present: egen total = total(first)
drop first

tab state_fips total

replace county_fips = 0 if total != `num_years'
drop total

** =============================================================================
** Collapse to County x Year x QC Panel (03_sdid_county.do:138-148)
** =============================================================================

collapse ///
    (mean) `outcomes' `controls' ///
    (sum) pop = n ///
    [fw = weight], by(state_fips county_fips qc_present year)

summ

** =============================================================================
** Reshape and Difference Variables (03_sdid_county.do:150-199)
** =============================================================================

reshape wide `outcomes' `controls' pop, i(state_fips county_fips year) j(qc_present)

gen pop = pop0 + pop1

foreach cov of local controls {
    gen `cov' = (`cov'0 * pop0 + `cov'1 * pop1) / pop
}

foreach out of local outcomes {

    dis "Processing outcome variable: `out'"

    gen missing0 = missing(`out'0)
    gen missing1 = missing(`out'1)

    by state_fips county_fips: egen max_m_`out'0 = max(missing0)
    by state_fips county_fips: egen max_m_`out'1 = max(missing1)

    tab state_fips, sum(max_m_`out'0)
    tab state_fips, sum(max_m_`out'1)

    drop missing* max_m_`out'*

    gen `out'_diff = `out'1 - `out'0

    rename `out'1 `out'
    rename `out'0 `out'_qc0

}

tab state_fips

** =============================================================================
** Treatment Variable and IDs (03_sdid_county.do:201-222)
** =============================================================================

gen treated = (state_fips == 6) & (year >= 2015)

egen fips = group(state_fips county_fips)

gen constant = 1

order state_fips county_fips fips year treated

qui count
dis "Panel rows: " r(N)

save "${data}interim/sdid_county_panel.dta", replace

dis "STAGE 10 COMPLETE"
log close _all
