/*******************************************************************************
File Name:      03_tab_intensive.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates intensive margin table and accompanying coefficient plot
                Triple-difference estimates of the effect of the CalEITC
                on hours worked, weeks worked, and weekly employment.

                Uses utility programs: run_triple_diff, add_spec_indicators,
                add_table_stats, make_table_coefplot

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_tab_intensive
log using "${logs}03_tab_intensive_log_${date}", name(log_03_tab_intensive) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define outcome variables
local outcomes "hours_worked_y weeks_worked_y employed_w"

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
use weight `outcomes' `controls' `unemp' `minwage' qc_* year ///
    female married in_school age citizen_test state_fips state_status ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        inrange(age, 20, 50) & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", clear

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

** Local count
local ct = 1

** Clear stored values
eststo clear

** Loop over outcome variables
foreach out of local outcomes {

    ** For hours and weeks, keep in levels (not percentage points)
    ** For employed_w, scale to percentage points
    if "`out'" == "employed_w" {
        replace `out' = `out' * 100
    }

    ** SPEC 1: Basic triple-diff FEs only
    eststo est_`out'_1: ///
        run_triple_diff `out', ///
            treatvar(treated) ///
            fes(`did_base') ///
            weightvar(weight) ///
            clustervar(`clustervar')

    add_table_stats, outcome(`out') treatvar(treated) ///
        postvar(post) statevar(ca) qcvar(qc_present) weightvar(weight)
    add_spec_indicators, spec(1)

    ** SPEC 2: Add demographic controls
    eststo est_`out'_2: ///
        run_triple_diff `out', ///
            treatvar(treated) ///
            controls(`controls') ///
            fes(`did_base') ///
            weightvar(weight) ///
            clustervar(`clustervar')

    add_table_stats, outcome(`out') treatvar(treated) ///
        postvar(post) statevar(ca) qcvar(qc_present) weightvar(weight)
    add_spec_indicators, spec(2)

    ** SPEC 3: Add unemployment controls
    eststo est_`out'_3: ///
        run_triple_diff `out', ///
            treatvar(treated) ///
            controls(`controls') ///
            unempvar(`unemp') ///
            fes(`did_base') ///
            weightvar(weight) ///
            clustervar(`clustervar') ///
            qcvar(qc_ct)

    add_table_stats, outcome(`out') treatvar(treated) ///
        postvar(post) statevar(ca) qcvar(qc_present) weightvar(weight)
    add_spec_indicators, spec(3)

    ** SPEC 4: Add minimum wage controls
    eststo est_`out'_4: ///
        run_triple_diff `out', ///
            treatvar(treated) ///
            controls(`controls') ///
            unempvar(`unemp') ///
            minwagevar(`minwage') ///
            fes(`did_base') ///
            weightvar(weight) ///
            clustervar(`clustervar') ///
            qcvar(qc_ct)

    add_table_stats, outcome(`out') treatvar(treated) ///
        postvar(post) statevar(ca) qcvar(qc_present) weightvar(weight)
    add_spec_indicators, spec(4)

    ** Export table for this outcome (labels use | separator)
    local stats_list "N r2_a ymean C"
    local stats_fmt "%9.0fc %9.3fc %9.1fc %9.0fc"

	** Define statistics labels
	local stats_labels `" "  Observations" "'
	local stats_labels `" `stats_labels' "  Adj. R-Square" "'
	local stats_labels `" `stats_labels' "  Treated group mean in pre-period" "'
	local stats_labels `" `stats_labels' "  Implied effect" "'

	** Save table locally
	esttab 	est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4	using			///
		"${results}tables/tab_intensive_`ct'.tex",							///
		booktabs fragment nobaselevels replace nomtitles nonumbers nolines	///
		stats(`stats_list', 												///
				fmt("`stats_fmt'") 											///
				labels(`stats_labels'))										///
		b(1) se(1) label order( treated) keep( treated) 					///
		star(* 0.10 ** 0.05 *** 0.01)										///
		prehead("\\ \midrule")


	** Save to overleaf if ${overleaf} == 1
	if ${overleaf} == 1 {
		esttab 	est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4	using			///
			"${ol_tab}tab_intensive_`ct'.tex",									///
			booktabs fragment nobaselevels replace nomtitles nonumbers nolines	///
			stats(`stats_list', 												///
					fmt("`stats_fmt'") 											///
					labels(`stats_labels'))										///
			b(1) se(1) label order( treated) keep( treated) 					///
			star(* 0.10 ** 0.05 *** 0.01)										///
			prehead("\\ \midrule")


	}

    ** For first outcome, create spec indicators table
    if `ct' == 1 {

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
		esttab	est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4	using			///
			"${results}tables/tab_intensive_end.tex",							///
			booktabs fragment nobaselevels replace nomtitles nonumbers nolines	///
			stats(`stats_list', 												///
				fmt("`stats_fmt'") 												///
				labels(`stats_labels'))											///
			cells(none) prehead("\\ \midrule")

		if ${overleaf} == 1 {

			esttab	est_`out'_1 est_`out'_2 est_`out'_3 est_`out'_4	using			///
				"${ol_tab}tab_intensive_end.tex",									///
				booktabs fragment nobaselevels replace nomtitles nonumbers nolines	///
				stats(`stats_list', 												///
					fmt("`stats_fmt'") 												///
					labels(`stats_labels'))											///
				cells(none) prehead("\\ \midrule")
		}


    }



    ** Update count
    local ct = `ct' + 1

}

** =============================================================================
** Create coefficient plot figure
** =============================================================================

** Define outcome labels for panel titles (| separated)
local out_labels "Annual hours worked|Annual weeks worked|Employed last week"

** Define specification labels (| separated)
local spec_labels "No Controls|Individual Controls|Add Unemployment|Add Minimum Wage"

** Create coefficient plot using utility
make_table_coefplot, ///
    outcomes(hours_worked_y weeks_worked_y employed_w) ///
    outlabels(`out_labels') ///
    specprefix(est_) ///
    numspecs(4) ///
    speclabels(`spec_labels') ///
    ytitle("Effect of the CalEITC") ///
    ymin(-1) ymax(1) ycut(.5) ///
    savepath("${results}figures/fig_tab_intensive.png")

** Also save as JPG for paper
graph export "${results}figures/fig_tab_intensive.jpg", as(jpg) quality(100) replace

** Save to Overleaf if enabled
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_tab_intensive.png", as(png) width(2400) height(1200) replace
}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_tab_intensive
