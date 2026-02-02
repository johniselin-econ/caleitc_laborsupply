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
** Program to store SDID results as estimation results
** =============================================================================

capture program drop store_sdid_results
program define store_sdid_results, eclass
    syntax, att(real) se(real) n(integer) outcome(string)

    ** Create matrices for ereturn post
    tempname b V
    matrix `b' = (`att')
    matrix `V' = (`se'^2)
    matrix colnames `b' = "ATT"
    matrix colnames `V' = "ATT"
    matrix rownames `V' = "ATT"

    ** Post results
    ereturn post `b' `V', obs(`n')
    ereturn local depvar "`outcome'"
    ereturn local cmd "sdid"

    ** Store ATT and SE for later use
    ereturn scalar ATT = `att'
    ereturn scalar se = `se'

end

** =============================================================================
** Load and Prepare Data
** =============================================================================

** Load ACS data with sample restrictions
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

** Store panel size
qui count
local N_panel = r(N)

** Save prepared data
save "${data}interim/sdid_county_panel.dta", replace

** =============================================================================
** Run SDID Regressions
** =============================================================================

** Counter for table panels
local i = 1

** Loop over outcomes
foreach out of local outcomes {

    dis ""
    dis "=============================================="
    dis "Running SDID for outcome: `out'"
    dis "=============================================="

    ** Clear stored estimates for this outcome
    eststo clear

    ** Start column counter
    local ct = 1

    ** Loop over 2D (Basic) vs 3D (Triple)
    foreach mod in "2D" "3D" {

        ** Set outcome suffix
        if "`mod'" == "3D" local prx "_diff"
        else local prx ""

        ** Loop over inclusion of controls
        forvalues c = 0/1 {

            ** Set control text (sdid_wt)
            if `c' == 1 local c_txt "covyn(1) covarlist(`controls_`mod'')"
            else local c_txt ""

            ** Identify loop
            dis ""
            dis "----------------------------------------------"
            dis "  - Model: `mod'"
            dis "  - Covariates: `c'"
            dis "----------------------------------------------"

            ** -----------------------------------------------------------------
            ** Population-weighted SDID (main results)
            ** -----------------------------------------------------------------
            dis "Running sdid_wt (population-weighted)..."
            sdid_wt `out'`prx' fips year treated, ///
                weight(pop) bs(`B') `c_txt'

            return list

            local tmp_att = r(ate)
            local tmp_se = r(se)

            ** Store as estimation result
            store_sdid_results, att(`tmp_att') se(`tmp_se') n(`N_panel') outcome(`out')

            ** Store estimate
            eststo est_`ct'

            ** Update column counter
            local ct = `ct' + 1

        }

    }

    ** -------------------------------------------------------------------------
    ** Export table for this outcome
    ** -------------------------------------------------------------------------

    ** Save table locally
    esttab est_1 est_2 est_3 est_4 using ///
        "${results}tables/tab_sdid_county_`i'.tex", ///
        booktabs fragment replace nonumbers nolines ///
        b(2) se(2) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats(N, fmt(%9.0fc) labels("Observations")) ///
        prehead("\\ \midrule")

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        esttab est_1 est_2 est_3 est_4 using ///
            "${ol_tab}tab_sdid_county_`i'.tex", ///
            booktabs fragment replace nonumbers nolines ///
            b(2) se(2) ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            stats(N, fmt(%9.0fc) labels("Observations")) ///
            prehead("\\ \midrule")
    }

    ** For first outcome, create spec indicators table
    if `i' == 1 {

        ** Add spec indicators
        est restore est_1
        estadd local basic "\checkmark"
        estadd local triple ""
        estadd local covars ""
        est store est_1

        est restore est_2
        estadd local basic "\checkmark"
        estadd local triple ""
        estadd local covars "\checkmark"
        est store est_2

        est restore est_3
        estadd local basic ""
        estadd local triple "\checkmark"
        estadd local covars ""
        est store est_3

        est restore est_4
        estadd local basic ""
        estadd local triple "\checkmark"
        estadd local covars "\checkmark"
        est store est_4

        ** Define statistics labels
        local stats_list "basic triple covars"
        local stats_fmt "%9s %9s %9s"
        local stats_labels `" "  Basic SDID (QC $>$ 0 only)" "  Triple SDID (Difference)" "  Time-varying Covariates" "'

        ** Save
        esttab est_1 est_2 est_3 est_4 using ///
            "${results}tables/tab_sdid_county_end.tex", ///
            booktabs fragment replace nonumbers nolines nomtitles ///
            stats(`stats_list', ///
                fmt("`stats_fmt'") ///
                labels(`stats_labels')) ///
            cells(none) prehead("\\ \midrule")

        if ${overleaf} == 1 {
            esttab est_1 est_2 est_3 est_4 using ///
                "${ol_tab}tab_sdid_county_end.tex", ///
                booktabs fragment replace nonumbers nolines nomtitles ///
                stats(`stats_list', ///
                    fmt("`stats_fmt'") ///
                    labels(`stats_labels')) ///
                cells(none) prehead("\\ \midrule")
        }

    }

    ** Update counter
    local i = `i' + 1

}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_sdid_county
