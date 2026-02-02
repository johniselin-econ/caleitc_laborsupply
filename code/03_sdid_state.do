/*******************************************************************************
File Name:      03_sdid_state.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates SDID Table 1: State Panel Synthetic DID Estimates

                Produces:
                - Basic SDID: Estimates on QC > 0 sample only
                - Triple SDID: Estimates on difference (QC > 0) - (QC = 0)
                - With and without time-varying covariates
                - Event-study estimates using sdid_event()

                Outcomes:
                - Employed last year
                - Employed full-time
                - Employed part-time
                - Earnings (Real 2019 USD)

                Covariates: State unemployment, state minimum wage

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_sdid_state
log using "${logs}03_sdid_state_log_${date}", name(log_03_sdid_state) replace text

** =============================================================================
** Setup
** =============================================================================

** Number of bootstrap replications
local B = 100

** Define outcomes
local outcomes "employed_y full_time_y part_time_y incearn_real"

** Define covariates for SDID
local controls "state_unemp mean_st_mw"

** Define start and end dates
local start = 2010
local end = ${end_year}

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
use weight `outcomes' `controls' qc_* year education					///
    female married in_school age_sample_20_49 citizen_test state_fips state_status 	///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", clear

** Scale employment outcomes to percentage points
foreach out in employed_y full_time_y part_time_y {
    replace `out' = 100 * `out'
}

** Generate count variable for collapsing
gen n = 1

** Store sample size before collapse
qui count
local N_micro = r(N)

** =============================================================================
** Collapse to State x Year x QC Panel
** =============================================================================

collapse ///
    (mean) `outcomes' `controls' ///
    (sum) pop = n ///
    [fw = weight], by(state_fips qc_present year)

** Summarize collapsed data
summ

** Store panel size
qui count
local N_panel = r(N)

** =============================================================================
** Reshape to Create Difference Variables for Triple SDID
** =============================================================================

** Reshape wide by QC status
reshape wide `outcomes' `controls' pop, i(state_fips year) j(qc_present)

** Generate total population weight
gen pop = pop0 + pop1

** For covariates, create overall average (weighted by QC group populations)
foreach cov of local controls {
    gen `cov' = (`cov'0 * pop0 + `cov'1 * pop1) / pop
}

** For each outcome, create difference variable for Triple SDID
foreach out of local outcomes {

    dis "Processing outcome variable: `out'"

    ** Check for missing values
    gen missing0 = missing(`out'0)
    gen missing1 = missing(`out'1)

    ** Count states with missing values
    by state_fips: egen max_m_`out'0 = max(missing0)
    by state_fips: egen max_m_`out'1 = max(missing1)

    ** Display missing patterns
    tab state_fips, sum(max_m_`out'0)
    tab state_fips, sum(max_m_`out'1)

    ** Drop temp variables
    drop missing* max_m_`out'*

    ** Generate difference: (QC > 0) - (QC = 0)
    gen `out'_diff = `out'1 - `out'0

    ** Rename QC > 0 value for clarity
    rename `out'1 `out'
    rename `out'0 `out'_qc0

}

** =============================================================================
** Generate Treatment Variable
** =============================================================================

** Treatment: California post-2014
gen treated = (state_fips == 6) & (year >= 2015)

** Generate constant weight for unweighted analysis
gen constant = 1

** Order variables
order state_fips year treated

** Store final panel size
qui count
local N_final = r(N)

** Save prepared data
save "${data}interim/sdid_state_panel.dta", replace

** =============================================================================
** Run SDID Regressions
** =============================================================================

** Define control variable lists
local controls_2D "state_unemp1 mean_st_mw1"
local controls_3D "state_unemp mean_st_mw"

** Counter for table panels
local i = 1

** Loop over outcomes
foreach out of local outcomes {

    dis ""
    dis "=============================================="
    dis "Running SDID for outcome: `out'"
    dis "=============================================="

    ** Clear stored estimates
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

            ** Set control variables
            if `c' == 1 & "`mod'" == "2D" local covars "`controls_2D'"
            else if `c' == 1 & "`mod'" == "3D" local covars "`controls_3D'"
            else local covars ""

            ** Set covariate text for sdid command
            if `c' == 1 local c_txt "covariates(`covars', projected)"
            else local c_txt ""

            ** Identify loop
            dis ""
            dis "----------------------------------------------"
            dis "  - Model: `mod'"
            dis "  - Covariates: `c'"
            dis "----------------------------------------------"

            ** Run SDID
            sdid `out'`prx' state_fips year treated, ///
                vce(placebo) `c_txt' reps(`B')

            ** Store ATT and SE
            local tmp_att = e(ATT)
            local tmp_se = e(se)

            ** Store as estimation result
            store_sdid_results, att(`tmp_att') se(`tmp_se') n(`N_final') outcome(`out')

            ** Store estimate
            eststo est_`ct'

            ** Update column counter
            local ct = `ct' + 1

        }

    }

    ** -------------------------------------------------------------------------
    ** Export table for this outcome
    ** -------------------------------------------------------------------------

    ** Define column titles
    local coltitles `" "(1)" "(2)" "(3)" "(4)" "'

    ** Save table locally
    esttab est_1 est_2 est_3 est_4 using ///
        "${results}tables/tab_sdid_state_`i'.tex", ///
        booktabs fragment replace nonumbers nolines ///
        mtitles(`coltitles') ///
        b(2) se(2) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats(N, fmt(%9.0fc) labels("Observations")) ///
        prehead("\\ \midrule")

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        esttab est_1 est_2 est_3 est_4 using ///
            "${ol_tab}tab_sdid_state_`i'.tex", ///
            booktabs fragment replace nonumbers nolines ///
            mtitles(`coltitles') ///
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
            "${results}tables/tab_sdid_state_end.tex", ///
            booktabs fragment replace nonumbers nolines nomtitles ///
            stats(`stats_list', ///
                fmt("`stats_fmt'") ///
                labels(`stats_labels')) ///
            cells(none) prehead("\\ \midrule")

        if ${overleaf} == 1 {
            esttab est_1 est_2 est_3 est_4 using ///
                "${ol_tab}tab_sdid_state_end.tex", ///
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
** Event Study Estimates using sdid_event()
** =============================================================================

dis ""
dis "=============================================="
dis "Running SDID Event Studies"
dis "=============================================="

foreach out of local outcomes {

    ** Loop over Basic (2D) and Triple (3D)
    foreach mod in "2D" "3D" {

        ** Set outcome suffix
        if "`mod'" == "3D" local prx "_diff"
        else local prx ""

        ** Set model label
        if "`mod'" == "2D" local mod_lbl "basic"
        else local mod_lbl "triple"

        ** Set covariates
        if "`mod'" == "2D" local covars "`controls_2D'"
        else local covars "`controls_3D'"

        dis ""
        dis "Event study: `out'`prx' (`mod_lbl')"

        ** Run SDID with event study (with covariates)
        sdid_event `out'`prx' state_fips year treated, ///
           vce(placebo) brep(50) placebo(all) covariates(`covars')

		** Preserve data and export into dataset
        mat res = e(H)
        svmat res
		gen id = _n - 1 if !missing(res1)
		replace id = . if id == 0
		replace id = 2010 + id - 4 if id >= 4
		replace id = 2014 + id if inlist(id, 1, 2, 3)
		sort id

		** Plot
        twoway 	(rcap res3 res4 id, color(gs7)) 				///
				(scatter res1 id, color(black) ms(d)), 			///
			legend(off) xtitle(Year)							///
            ytitle(Average Treatment Effect) 					///
			xline(2014.5, lc(red) lp(-)) yline(0, lc(black) lp(solid))

		drop id res1-res5

        ** Save event study figure
        graph export "${results}tables/fig_sdid_event_`out'_`mod_lbl'.jpg", ///
            as(jpg) quality(100) replace

        if ${overleaf} == 1 {
            graph export "${ol_fig}fig_sdid_event_`out'_`mod_lbl'.jpg", ///
                as(jpg) quality(100) replace
        }

    }

}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_sdid_state
