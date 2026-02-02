/*******************************************************************************
File Name:      03_tab_earnings.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Table 5
                Triple-difference estimates of the effect of the CalEITC
                on annual earnings (OLS and PPML)

                Uses utility programs: run_triple_diff, run_ppml_regression,
                add_spec_indicators

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_tab_earnings
log using "${logs}03_tab_earnings_log_${date}", name(log_03_tab_earnings) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define outcome variable
local outcome "incearn_real"

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

** =============================================================================
** Load data and define sample
** =============================================================================

** Load ACS data
use weight `outcome' `controls' `unemp' `minwage' qc_* year ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using ${data}final/acs_working_file, clear

** Handle missing earned income
replace `outcome' = 0 if `outcome' == .

** Create main DID variables
gen ca = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)
label var treated "ATE"

** Update adults per HH (cap at 3)
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** =============================================================================
** Run regressions and export tables
** =============================================================================

** Clear stored values
eststo clear

** Loop over models (1=OLS all, 2=OLS positive, 3=PPML)
forvalues m = 1/3 {

    ** Define sample conditions
    if `m' == 1 gen sample = `outcome' >= 0 & !missing(`outcome')
    if `m' == 2 gen sample = `outcome' > 0 & !missing(`outcome')
    if `m' == 3 gen sample = `outcome' >= 0 & !missing(`outcome')

    ** SPEC 1: Basic triple-diff FEs only
    if `m' < 3 {
        eststo est_`m'_1: ///
            run_triple_diff `outcome' if sample == 1, ///
                treatvar(treated) ///
                fes(`did_base') ///
                weightvar(weight) ///
                clustervar(`clustervar')
    }
    else {
        eststo est_`m'_1: ///
            run_ppml_regression `outcome', ///
                treatvar(treated) ///
                fes(`did_base') ///
                weightvar(weight) ///
                clustervar(`clustervar') ///
                samplecond(sample == 1)
        estadd scalar AME = r(AME)
    }

    ** Get pre-period treated mean
    qui summ `outcome' if sample == 1 & post == 0 & ca == 1 & qc_present == 1 [aw=weight]
    estadd scalar ymean = r(mean)
    add_spec_indicators, spec(1)

    ** SPEC 2: Add demographic controls
    if `m' < 3 {
        eststo est_`m'_2: ///
            run_triple_diff `outcome' if sample == 1, ///
                treatvar(treated) ///
                controls(`controls') ///
                fes(`did_base') ///
                weightvar(weight) ///
                clustervar(`clustervar')
    }
    else {
        eststo est_`m'_2: ///
            run_ppml_regression `outcome', ///
                treatvar(treated) ///
                controls(`controls') ///
                fes(`did_base') ///
                weightvar(weight) ///
                clustervar(`clustervar') ///
                samplecond(sample == 1)
        estadd scalar AME = r(AME)
    }

    qui summ `outcome' if sample == 1 & post == 0 & ca == 1 & qc_present == 1 [aw=weight]
    estadd scalar ymean = r(mean)
    add_spec_indicators, spec(2)

    ** SPEC 3: Add unemployment controls
    if `m' < 3 {
        eststo est_`m'_3: ///
            run_triple_diff `outcome' if sample == 1, ///
                treatvar(treated) ///
                controls(`controls') ///
                unempvar(`unemp') ///
                fes(`did_base') ///
                weightvar(weight) ///
                clustervar(`clustervar') ///
                qcvar(qc_ct)
    }
    else {
        eststo est_`m'_3: ///
            run_ppml_regression `outcome', ///
                treatvar(treated) ///
                controls(`controls') ///
                unempvar(`unemp') ///
                fes(`did_base') ///
                weightvar(weight) ///
                clustervar(`clustervar') ///
                qcvar(qc_ct) ///
                samplecond(sample == 1)
        estadd scalar AME = r(AME)
    }

    qui summ `outcome' if sample == 1 & post == 0 & ca == 1 & qc_present == 1 [aw=weight]
    estadd scalar ymean = r(mean)
    add_spec_indicators, spec(3)

    ** SPEC 4: Add minimum wage controls
    if `m' < 3 {
        eststo est_`m'_4: ///
            run_triple_diff `outcome' if sample == 1, ///
                treatvar(treated) ///
                controls(`controls') ///
                unempvar(`unemp') ///
                minwagevar(`minwage') ///
                fes(`did_base') ///
                weightvar(weight) ///
                clustervar(`clustervar') ///
                qcvar(qc_ct)
    }
    else {
        eststo est_`m'_4: ///
            run_ppml_regression `outcome', ///
                treatvar(treated) ///
                controls(`controls') ///
                unempvar(`unemp') ///
                minwagevar(`minwage') ///
                fes(`did_base') ///
                weightvar(weight) ///
                clustervar(`clustervar') ///
                qcvar(qc_ct) ///
                samplecond(sample == 1)
        estadd scalar AME = r(AME)
    }

    qui summ `outcome' if sample == 1 & post == 0 & ca == 1 & qc_present == 1 [aw=weight]
    estadd scalar ymean = r(mean)
    add_spec_indicators, spec(4)

    ** Define statistics and formatting for export
    if `m' < 3 {
        local stats_list "N r2_a ymean"
        local stats_fmt "%9.0fc %9.3fc %9.0fc"
        local dig = 1

		** Define statistics labels
		local stats_labels `" "  Observations" "'
		local stats_labels `" `stats_labels' "  Adj. R-Square" "'
		local stats_labels `" `stats_labels' "  Treated group mean in pre-period" "'
    }
    else {
        local stats_list "N r2_p ymean AME"
        local stats_fmt "%9.0fc %9.3fc %9.0fc %9.0fc"
        local dig = 2

		** Define statistics labels
		local stats_labels `" "  Observations" "'
		local stats_labels `" `stats_labels' "  Pseudo R-squared" "'
		local stats_labels `" `stats_labels' "  Treated group mean in pre-period" "'
		local stats_labels `" `stats_labels' "  Effect in USD" "'
    }

	** Save table locally
	esttab 	est_`m'_1 est_`m'_2 est_`m'_3 est_`m'_4 using					///
		"${results}tables/tab_earnings_`m'.tex",										///
		booktabs fragment nobaselevels replace nomtitles nonumbers nolines	///
		stats(`stats_list', 												///
				fmt("`stats_fmt'") 											///
				labels(`stats_labels'))										///
		b(`dig') se(`dig') label order(treated) keep(treated) 				///
		star(* 0.10 ** 0.05 *** 0.01)										///
		prehead("\\ \midrule")

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
		esttab 	est_`m'_1 est_`m'_2 est_`m'_3 est_`m'_4 using					///
			"${ol_tab}tab_earnings_`m'.tex",											///
			booktabs fragment nobaselevels replace nomtitles nonumbers nolines	///
			stats(`stats_list', 												///
					fmt("`stats_fmt'") 											///
					labels(`stats_labels'))										///
			b(`dig') se(`dig') label order(treated) keep(treated) 				///
			star(* 0.10 ** 0.05 *** 0.01)										///
			prehead("\\ \midrule")
    }

    ** For first model, create spec indicators table
    if `m' == 1 {

		** Define statistics to be included (indicators for controls)
		local stats_list "s1 s2 s3 s4"

		** Define statistics formats
		local stats_fmt "%9s %9s %9s %9s"

		** Define statistics labels
		local stats_labels `" "  Triple-Difference" "'
		local stats_labels `" `stats_labels' "  Add Demographic Controls" "'
		local stats_labels `" `stats_labels' "  Add Unemployment Controls" "'
		local stats_labels `" `stats_labels' "  Add Minimum Wage Controls" "'

		** Save
		esttab	est_`m'_1 est_`m'_2 est_`m'_3 est_`m'_4 using				///
			"${results}tables/tab_earnings_end.tex",									///
			booktabs fragment nobaselevels replace nomtitles nonumbers nolines	///
			stats(`stats_list', 											///
				fmt("`stats_fmt'") 											///
				labels(`stats_labels'))										///
			cells(none) prehead("\\ \midrule")

		if ${overleaf} == 1 {
			esttab	est_`m'_1 est_`m'_2 est_`m'_3 est_`m'_4 using				///
				"${ol_tab}tab_earnings_end.tex",										///
				booktabs fragment nobaselevels replace nomtitles nonumbers nolines	///
				stats(`stats_list', 											///
					fmt("`stats_fmt'") 											///
					labels(`stats_labels'))										///
				cells(none) prehead("\\ \midrule")
		}
    }

    ** Drop sample variable
    drop sample

}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_tab_earnings
