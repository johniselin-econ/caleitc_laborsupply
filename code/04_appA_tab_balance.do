/*******************************************************************************
File Name:      04_appA_tab_balance.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Appendix A Balance Table
                Triple-difference balance test for pre-treatment covariate balance

                Tests balance on: Hispanic, NH White, NH Black, Other Race,
                No HS, HS Only, Some College, 3+ Adult HH, Age

                Includes Romano-Wolf stepdown p-values and BKY (2006) sharpened
                q-values for multiple hypothesis testing corrections.

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_tab_balance
log using "${logs}04_appA_tab_balance_log_${date}", name(log_04_appA_tab_balance) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define balance test variables
local balvar "hisp nhw nhb oth nhs ohs sco hh3 age"

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
local did1 "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"

** SPEC 1: Base FEs only
local unemp1 ""
local mw1 ""

** SPEC 2: Add unemployment controls
local did2 "`did1'"
local unemp2 "c.`unemp'#i.qc_ct"
local mw2 ""

** SPEC 3: Add unemployment and minimum wage controls
local did3 "`did1'"
local unemp3 "`unemp2'"
local mw3 "c.`minwage'#i.qc_ct"

** =============================================================================
** Load data and define sample
** =============================================================================

** Load ACS data
use weight `unemp' `minwage' qc_* year race_hisp education hispanic ///
	female married in_school age age_sample_20_49 citizen_test state_fips state_status hh_adult_ct ///
	if 	female == 1 & ///
		married == 0 & ///
		in_school == 0 & ///
		age_sample_20_49 == 1 & ///
		citizen_test == 1 & ///
		education < 4 & ///
		state_status > 0 & ///
		inrange(year, `start', `end') ///
	using ${data}final/acs_working_file, clear

** Create main DID variables
gen ca = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)
label var treated "ATE"

** Update adults per HH (cap at 3)
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** Label minimum wage variable
label var mean_st_mw "Binding state minimum wage"

** =============================================================================
** Generate balance test covariates
** =============================================================================

** Race/ethnicity indicators
gen hisp = hispanic
gen nhw = race_hisp == 2
gen nhb = race_hisp == 3
gen oth = race_hisp == 4

** Education indicators
gen nhs = education == 1
gen ohs = education == 2
gen sco = education == 3

** Household composition
gen hh3 = hh_adult_ct >= 3

** =============================================================================
** Run regressions and export tables
** =============================================================================

** Loop over specifications
forvalues s = 1/3 {

	** Clear stored values
	eststo clear

	** Loop over set of balance variables
	foreach var of local balvar {

		** Run main regression
		eststo m`var'_s`s': quietly reghdfe `var' treated ///
			`unemp`s'' `mw`s'' ///
			[aw = weight], ///
			absorb(`did`s'') ///
			vce(cluster `clustervar')

		** Store p-values for q-values
		mat mat_p = r(table)
		local p_`var' = mat_p[4,1]

		** Store command for RW p-values
		local `var'_regtext "reghdfe `var' treated `unemp`s'' `mw`s'' [aw = weight], "
		local `var'_regtext "``var'_regtext' absorb(`did`s'') vce(cluster `clustervar')"

	} // END VARLIST LOOP

	** =========================================================================
	** Romano-Wolf stepdown p-values for multiple hypothesis testing
	** =========================================================================

	rwolf2 	(`hisp_regtext') (`nhw_regtext') (`nhb_regtext') (`oth_regtext') ///
			(`nhs_regtext') (`ohs_regtext') (`sco_regtext') ///
			(`hh3_regtext') (`age_regtext'), ///
			indepvars(treated, treated, treated, treated, treated, ///
					  treated, treated, treated, treated) reps(500)

	** Loop over balance variables to store RW p-values
	foreach var of local balvar {
		local p_rw_`var' = e(rw_`var'_treated)
	} // END VARLIST LOOP

	** =========================================================================
	** BKY (2006) sharpened two-stage q-values
	** =========================================================================

	** Preserve data
	preserve

	** Create variable to hold p-values
	quietly gen float pval = .
	local ct = 1

	** Fill in p-values
	foreach var of local balvar {
		replace pval = `p_`var'' if _n == `ct'
		local ct = `ct' + 1
	} // END VARLIST LOOP

	** Collect the total number of p-values tested
	quietly sum pval
	local totalpvals = r(N)

	** Sort the p-values in ascending order and generate rank variable
	quietly gen int original_sorting_order = _n
	quietly sort pval
	quietly gen int rank = _n if pval != .

	** Set the initial counter to 1
	local qval = 1

	** Generate the variable that will contain the BKY (2006) sharpened q-values
	gen bky06_qval = 1 if pval != .

	** Loop from q = 1.000 down to q = 0.001
	while `qval' > 0 {

		** First Stage
		local qval_adj = `qval' / (1 + `qval')
		gen fdr_temp1 = `qval_adj' * rank / `totalpvals'
		gen reject_temp1 = (fdr_temp1 >= pval) if pval != .
		gen reject_rank1 = reject_temp1 * rank
		egen total_rejected1 = max(reject_rank1)

		** Second Stage
		local qval_2st = `qval_adj' * (`totalpvals' / (`totalpvals' - total_rejected1[1]))
		gen fdr_temp2 = `qval_2st' * rank / `totalpvals'
		gen reject_temp2 = (fdr_temp2 >= pval) if pval != .
		gen reject_rank2 = reject_temp2 * rank
		egen total_rejected2 = max(reject_rank2)

		** Update q-values
		replace bky06_qval = `qval' if rank <= total_rejected2 & rank != .

		** Clean up and reduce q
		drop fdr_temp* reject_temp* reject_rank* total_rejected*
		local qval = `qval' - .001
	}

	quietly sort original_sorting_order

	** Loop over balance variables to get BKY q-values
	local ct = 1
	foreach var of local balvar {
		local q_bky_`var' = bky06_qval[`ct']
		local ct = `ct' + 1
	} // END VARLIST LOOP

	** Restore data
	restore

	** =========================================================================
	** Add statistics and export tables
	** =========================================================================

	** Loop over balance variables and append q-values and p-values
	foreach var of local balvar {
		estadd scalar p = `p_`var'' : m`var'_s`s'
		estadd scalar pRW = `p_rw_`var'': m`var'_s`s'
		estadd scalar qBKY = `q_bky_`var'': m`var'_s`s'
	} // END VARLIST LOOP

	** Change label
	label var treated "Treatment"

	** Save table locally
	esttab using "${results}tables/tab_appA_balance_`s'.tex", ///
		booktabs nobaselevels replace style(tex) ///
		stats(p pRW qBKY N r2, fmt(%9.3f %9.3f %9.3f %9.0fc %9.3f) ///
			labels("Unadjusted p-values" ///
				   "Romano Wolf p-values" ///
				   "BKY (2006) sharpened q-values" ///
				   "Observations" "R-Squared")) ///
		b(3) se(3) label keep(treated) ///
		star(* 0.10 ** 0.05 *** 0.01) ///
		mlabels("Hispanic" "NH White" "NH Black" ///
				"Other race" "No HS" "HS Only" ///
				"Some College" "3+ adult HH" "Age")

	** Save to Overleaf if enabled
	if ${overleaf} == 1 {
		esttab using "${ol_tab}tab_appA_balance_`s'.tex", ///
			booktabs nobaselevels replace style(tex) ///
			stats(p pRW qBKY N r2, fmt(%9.3f %9.3f %9.3f %9.0fc %9.3f) ///
				labels("Unadjusted p-values" ///
					   "Romano Wolf p-values" ///
					   "BKY (2006) sharpened q-values" ///
					   "Observations" "R-Squared")) ///
			b(3) se(3) label keep(treated) ///
			star(* 0.10 ** 0.05 *** 0.01) ///
			mlabels("Hispanic" "NH White" "NH Black" ///
					"Other race" "No HS" "HS Only" ///
					"Some College" "3+ adult HH" "Age")
	}

} // END SPEC LOOP

** =============================================================================
** End
** =============================================================================

clear
log close log_04_appA_tab_balance
