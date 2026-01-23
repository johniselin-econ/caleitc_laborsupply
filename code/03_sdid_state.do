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
** Load and Prepare Data
** =============================================================================

** Load ACS data with sample restrictions
use weight `outcomes' `controls' qc_* year education					///
    female married in_school age citizen_test state_fips state_status 	///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        inrange(age, 20, 50) & ///
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

** =============================================================================
** Collapse to State x Year x QC Panel
** =============================================================================

collapse ///
    (mean) `outcomes' `controls' ///
    (sum) pop = n ///
    [fw = weight], by(state_fips qc_present year)

** Summarize collapsed data
summ

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

    ** Drop QC = 0 value (keep for Basic SDID)
    ** rename `out'0 `out'_qc0

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

    ** Create matrices to store results (2 rows: ATT, SE; 4 cols: specifications)
    matrix table_`out' = J(2, 4, .)
    matrix rownames table_`out' = ATT SE
    matrix colnames table_`out' = "Basic_NoCov" "Basic_Cov" "Triple_NoCov" "Triple_Cov"

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
            dis "=============================================="
            dis "Running SDID"
            dis "  - Outcome: `out'`prx'"
            dis "  - Model: `mod'"
            dis "  - Covariates: `covars'"
            dis "=============================================="

            ** Run SDID
            sdid `out'`prx' state_fips year treated, ///
                vce(placebo) `c_txt' reps(`B')

            ** Store results
            local att_`ct' = `e(ATT)'
            local se_`ct' = `e(se)'

            matrix table_`out'[1, `ct'] = `att_`ct''
            matrix table_`out'[2, `ct'] = `se_`ct''

            ** Update column counter
            local ct = `ct' + 1

        }

    }

    ** Display matrix
    dis ""
    dis "Results for `out':"
    matrix list table_`out'

    ** Export matrix to LaTeX
    esttab matrix(table_`out', fmt(%9.2fc)) ///
        using "${results}paper/tab_sdid_state_`i'.tex", ///
        replace booktabs fragment mlabels(,none) ///
        collabels(,none) nonumbers nolines

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        esttab matrix(table_`out', fmt(%9.2fc)) ///
            using "${ol_tab}tab_sdid_state_`i'.tex", ///
            replace booktabs fragment mlabels(,none) ///
            collabels(,none) nonumbers nolines
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

** Reset counter
local i = 1

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
        sdid_event `out'`prx' state_fips year treated, 				///
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
        graph export "${results}paper/fig_sdid_event_`out'_`mod_lbl'.jpg", ///
            as(jpg) quality(100) replace

        if ${overleaf} == 1 {
            graph export "${ol_fig}fig_sdid_event_`out'_`mod_lbl'.jpg", ///
                as(jpg) quality(100) replace
        }

    }

}

** =============================================================================
** Create Summary Table Combining All Outcomes
** =============================================================================

** Create combined results matrix
matrix results_all = J(8, 4, .)
matrix rownames results_all = ///
    "Employed_ATT" "Employed_SE" ///
    "FullTime_ATT" "FullTime_SE" ///
    "PartTime_ATT" "PartTime_SE" ///
    "Earnings_ATT" "Earnings_SE"
matrix colnames results_all = "Basic_NoCov" "Basic_Cov" "Triple_NoCov" "Triple_Cov"

** Fill in from individual outcome matrices
local row = 1
foreach out of local outcomes {
    matrix results_all[`row', 1] = table_`out'[1, 1..4]
    matrix results_all[`row'+1, 1] = table_`out'[2, 1..4]
    local row = `row' + 2
}

** Display combined results
dis ""
dis "=============================================="
dis "Combined SDID Results (State Panel)"
dis "=============================================="
matrix list results_all

** Export combined table
esttab matrix(results_all, fmt(%9.2fc)) ///
    using "${results}paper/tab_sdid_state_combined.tex", ///
    replace booktabs fragment mlabels(,none) ///
    collabels(,none) nonumbers nolines

if ${overleaf} == 1 {
    esttab matrix(results_all, fmt(%9.2fc)) ///
        using "${ol_tab}tab_sdid_state_combined.tex", ///
        replace booktabs fragment mlabels(,none) ///
        collabels(,none) nonumbers nolines
}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_sdid_state
