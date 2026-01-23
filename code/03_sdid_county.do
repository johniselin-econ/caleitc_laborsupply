/*******************************************************************************
File Name:      03_sdid_county.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates SDID Table 2: County Panel Weighted SDID Estimates

                Produces:
                - Weighted SDID: Population-weighted estimates on QC > 0 sample
                - Weighted Triple SDID: Population-weighted estimates on difference
                - With and without time-varying covariates

                Uses the sdid_wt program for population-weighted estimation

                Outcomes:
                - Employed last year
                - Employed full-time
                - Employed part-time
                - Earnings (Real 2019 USD)

                Covariates: County unemployment, state minimum wage

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_sdid_county
log using "${logs}03_sdid_county_log_${date}", name(log_03_sdid_county) replace text

** =============================================================================
** Setup
** =============================================================================

** Load the weighted SDID program
run "${code}utils/sdid_wt.do"

** Number of bootstrap replications
local B = 100

** Define outcomes
local outcomes "employed_y full_time_y part_time_y incearn_real"

** Define start and end dates
local start = 2010
local end = ${end_year}

** Number of years in panel (for balance check)
local num_years = `end' - `start' + 1

** =============================================================================
** Load and Prepare Data
** =============================================================================

** Load ACS data with sample restrictions
use weight `outcomes' state_unemp county_unemp mean_st_mw qc_* year ///
    female married in_school age citizen_test state_fips county_fips state_status ///
    race_group hispanic education age_bracket ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        inrange(age, 20, 50) & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", clear

** =============================================================================
** Create Control Variables
** =============================================================================

** Rename unemployment and minwage for clarity
gen unemp = county_unemp
replace unemp = state_unemp if missing(unemp)
gen minwage = mean_st_mw

** Define control list
local controls "unemp minwage"

** Scale employment outcomes to percentage points
foreach out in employed_y full_time_y part_time_y {
    replace `out' = 100 * `out'
}

** Generate count variable
gen n = 1

** Keep required variables
keep year state_fips county_fips `outcomes' `controls' weight qc_present n

** =============================================================================
** Handle Unbalanced Panel - Group Small Counties
** =============================================================================

** Find unique observation per county x year x QC
bysort state_fips county_fips qc_present year: gen ct = _n
gen first = (ct == 1)
drop ct

** Count number of times county is observed across sample
bysort state_fips county_fips qc_present: egen total = total(first)
drop first

** Tabulation
tab state_fips total

** Replace county with 0 if not balanced (< num_years observations)
replace county_fips = 0 if total != `num_years'
drop total

** =============================================================================
** Collapse to County x Year x QC Panel
** =============================================================================

collapse ///
    (mean) `outcomes' `controls' ///
    (sum) pop = n ///
    [fw = weight], by(state_fips county_fips qc_present year)

** Summarize collapsed data
summ

** =============================================================================
** Reshape to Create Difference Variables for Triple SDID
** =============================================================================

** Reshape wide by QC status
reshape wide `outcomes' `controls' pop, i(state_fips county_fips year) j(qc_present)

** Generate total population weight
gen pop = pop0 + pop1

** For covariates, create overall average (weighted by QC group populations)
foreach cov of local controls {
    gen `cov' = (`cov'0 * pop0 + `cov'1 * pop1) / pop
}

** Define control variable lists for different models
local controls_2D "unemp1 minwage1"
local controls_3D "unemp minwage"

** For each outcome, check for missing and create difference variable
foreach out of local outcomes {

    dis "Processing outcome variable: `out'"

    ** Generate missing variable indicator
    gen missing0 = missing(`out'0)
    gen missing1 = missing(`out'1)

    ** Count counties where one period has a missing value
    by state_fips county_fips: egen max_m_`out'0 = max(missing0)
    by state_fips county_fips: egen max_m_`out'1 = max(missing1)

    ** Tabulation of missing by state
    tab state_fips, sum(max_m_`out'0)
    tab state_fips, sum(max_m_`out'1)

    ** Drop temp variables
    drop missing* max_m_`out'*

    ** Generate difference: (QC > 0) - (QC = 0)
    gen `out'_diff = `out'1 - `out'0

    ** Rename variables
    rename `out'1 `out'
    rename `out'0 `out'_qc0

}

** Print sample
fre state_fips

** =============================================================================
** Generate Treatment Variable and IDs
** =============================================================================

** Treatment: California post-2014
gen treated = (state_fips == 6) & (year >= 2015)

** Generate county X state unique ID (fips)
egen fips = group(state_fips county_fips)

** Generate constant weight for comparison
gen constant = 1

** Order variables
order state_fips county_fips fips year treated

** Save prepared data
save "${data}interim/sdid_county_panel.dta", replace

** =============================================================================
** Run SDID Regressions
** =============================================================================

** Counter for table panels
local i = 1

** Loop over outcomes
foreach out of local outcomes {

    ** Create matrices to store results
    ** Standard SDID (for comparison)
    matrix table_`out'_st = J(2, 4, .)
    ** Unweighted via sdid_wt (for validation)
    matrix table_`out'_nw = J(2, 4, .)
    ** Population-weighted SDID
    matrix table_`out'_wt = J(2, 4, .)

    ** Row and column names
    matrix rownames table_`out'_st = ATT SE
    matrix rownames table_`out'_nw = ATT SE
    matrix rownames table_`out'_wt = ATT SE
    matrix colnames table_`out'_st = "Basic_NoCov" "Basic_Cov" "Triple_NoCov" "Triple_Cov"
    matrix colnames table_`out'_nw = "Basic_NoCov" "Basic_Cov" "Triple_NoCov" "Triple_Cov"
    matrix colnames table_`out'_wt = "Basic_NoCov" "Basic_Cov" "Triple_NoCov" "Triple_Cov"

    ** Start column counter
    local ct = 1

    ** Loop over 2D (Basic) vs 3D (Triple)
    foreach mod in "2D" "3D" {

        ** Set outcome suffix
        if "`mod'" == "3D" local prx "_diff"
        else local prx ""

        ** Loop over inclusion of controls
        forvalues c = 0/1 {

            ** Set control text (standard sdid)
            if `c' == 1 local c_txt1 "covariates(`controls_`mod'', projected)"
            else local c_txt1 ""

            ** Set control text (sdid_wt)
            if `c' == 1 local c_txt2 "covyn(1) covarlist(`controls_`mod'')"
            else local c_txt2 ""

            ** Identify loop
            dis ""
            dis "=============================================="
            dis "Running SDID"
            dis "  - Outcome: `out'`prx'"
            dis "  - Model: `mod'"
            dis "  - Controls: `c'"
            dis "=============================================="

            ** -----------------------------------------------------------------
            ** Model 1: Standard (unweighted) SDID
            ** -----------------------------------------------------------------
            dis "Running standard SDID..."
            sdid `out'`prx' fips year treated, ///
                vce(bootstrap) `c_txt1' reps(`B')

            local att_`ct' = `e(ATT)'
            local se_`ct' = `e(se)'

            matrix table_`out'_st[1, `ct'] = `att_`ct''
            matrix table_`out'_st[2, `ct'] = `se_`ct''

            ** -----------------------------------------------------------------
            ** Model 2: Unweighted SDID via sdid_wt (validation)
            ** -----------------------------------------------------------------
            dis "Running sdid_wt (unweighted)..."
            sdid_wt `out'`prx' fips year treated, ///
                weight(constant) bs(`B') `c_txt2'

            return list

            local att_`ct' = `r(ate)'
            local se_`ct' = `r(se)'

            matrix table_`out'_nw[1, `ct'] = `att_`ct''
            matrix table_`out'_nw[2, `ct'] = `se_`ct''

            ** -----------------------------------------------------------------
            ** Model 3: Population-weighted SDID
            ** -----------------------------------------------------------------
            dis "Running sdid_wt (population-weighted)..."
            sdid_wt `out'`prx' fips year treated, ///
                weight(pop) bs(`B') `c_txt2'

            return list

            local att_`ct' = `r(ate)'
            local se_`ct' = `r(se)'

            matrix table_`out'_wt[1, `ct'] = `att_`ct''
            matrix table_`out'_wt[2, `ct'] = `se_`ct''

            ** Update column counter
            local ct = `ct' + 1

        }

    }

    ** Display matrices
    dis ""
    dis "Results for `out' (Standard SDID):"
    matrix list table_`out'_st

    dis ""
    dis "Results for `out' (Unweighted via sdid_wt):"
    matrix list table_`out'_nw

    dis ""
    dis "Results for `out' (Population-Weighted SDID):"
    matrix list table_`out'_wt

    ** -------------------------------------------------------------------------
    ** Export Tables
    ** -------------------------------------------------------------------------

    ** Export standard SDID
    esttab matrix(table_`out'_st, fmt(%9.2fc)) ///
        using "${results}paper/tab_sdid_county_`i'_standard.tex", ///
        replace booktabs fragment mlabels(,none) ///
        collabels(,none) nonumbers nolines

    ** Export weighted SDID (main table)
    esttab matrix(table_`out'_wt, fmt(%9.2fc)) ///
        using "${results}paper/tab_sdid_county_`i'_weighted.tex", ///
        replace booktabs fragment mlabels(,none) ///
        collabels(,none) nonumbers nolines

    ** Export unweighted via sdid_wt (for validation)
    esttab matrix(table_`out'_nw, fmt(%9.2fc)) ///
        using "${results}paper/tab_sdid_county_`i'_nonweighted.tex", ///
        replace booktabs fragment mlabels(,none) ///
        collabels(,none) nonumbers nolines

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {

        esttab matrix(table_`out'_st, fmt(%9.2fc)) ///
            using "${ol_tab}tab_sdid_county_`i'_standard.tex", ///
            replace booktabs fragment mlabels(,none) ///
            collabels(,none) nonumbers nolines

        esttab matrix(table_`out'_wt, fmt(%9.2fc)) ///
            using "${ol_tab}tab_sdid_county_`i'_weighted.tex", ///
            replace booktabs fragment mlabels(,none) ///
            collabels(,none) nonumbers nolines

        esttab matrix(table_`out'_nw, fmt(%9.2fc)) ///
            using "${ol_tab}tab_sdid_county_`i'_nonweighted.tex", ///
            replace booktabs fragment mlabels(,none) ///
            collabels(,none) nonumbers nolines

    }

    ** Update counter
    local i = `i' + 1

}

** =============================================================================
** Create Combined Summary Tables
** =============================================================================

** Create combined results matrix for weighted SDID
matrix results_weighted = J(8, 4, .)
matrix rownames results_weighted = ///
    "Employed_ATT" "Employed_SE" ///
    "FullTime_ATT" "FullTime_SE" ///
    "PartTime_ATT" "PartTime_SE" ///
    "Earnings_ATT" "Earnings_SE"
matrix colnames results_weighted = "Basic_NoCov" "Basic_Cov" "Triple_NoCov" "Triple_Cov"

** Fill in from individual outcome matrices
local row = 1
foreach out of local outcomes {
    matrix results_weighted[`row', 1] = table_`out'_wt[1, 1..4]
    matrix results_weighted[`row'+1, 1] = table_`out'_wt[2, 1..4]
    local row = `row' + 2
}

** Display combined results
dis ""
dis "=============================================="
dis "Combined Weighted SDID Results (County Panel)"
dis "=============================================="
matrix list results_weighted

** Export combined table
esttab matrix(results_weighted, fmt(%9.2fc)) ///
    using "${results}paper/tab_sdid_county_combined.tex", ///
    replace booktabs fragment mlabels(,none) ///
    collabels(,none) nonumbers nolines

if ${overleaf} == 1 {
    esttab matrix(results_weighted, fmt(%9.2fc)) ///
        using "${ol_tab}tab_sdid_county_combined.tex", ///
        replace booktabs fragment mlabels(,none) ///
        collabels(,none) nonumbers nolines
}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_sdid_county
