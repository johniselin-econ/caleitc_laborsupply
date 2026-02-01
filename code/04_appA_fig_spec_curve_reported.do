/*******************************************************************************
File Name:      04_appA_fig_spec_curve_reported.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix Figure: Specification Curves (Reported Hours/Weeks)

                Same as 03_fig_spec_curve.do but restricted to individuals with
                reported (non-imputed) hours and weeks worked:
                - hours_worked_y_reported == 1
                - weeks_worked_y_reported == 1

                Loops over:
                - Sample of states: No EITC change (default), no state EITC,
                  Medicaid-expansion states
                - Education sample: Low education vs all education
                - Age sample: 20-49 vs 20-64
                - Pre-period: Excluding 2010-11 vs including 2010-11
                - Inclusion of controls: Demographic, Unemployment X QC,
                  Minimum wage X QC

                Creates three sub-plots: Full-time, part-time, and
                overall employment

                Coefficient colors:
                - Dark blue (navy): Statistically significant (p<0.05)
                - Light blue: Statistically insignificant

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_fig_spec_curve_rep
log using "${logs}04_appA_fig_spec_curve_reported_log_${date}", ///
    name(log_04_appA_fig_spec_curve_rep) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define outcome variables
local outcomes "employed_y full_time_y part_time_y"

** Define control variables
local controls "education age_bracket minage_qc race_group hispanic hh_adult_ct"

** Define unemployment control variable
local unemp "state_unemp"

** Define minimum wage control variable
local minwage "mean_st_mw"

** Define cluster variable
local clustervar "state_fips"

** Define end date (start varies by specification)
local end = ${end_year}

** Base SPECIFICATION (FEs)
local did_base "qc_ct year state_fips"
local did_base "`did_base' state_fips#year"
local did_base "`did_base' state_fips#qc_ct"
local did_base "`did_base' year#qc_ct"

** =============================================================================
** Load data
** =============================================================================

** Load ACS data - including reported indicators
use weight `outcomes' `controls' `unemp' `minwage' qc_* year age education ///
    female married in_school citizen_test state_fips state_status ///
    hours_worked_y_reported weeks_worked_y_reported ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        citizen_test == 1 & ///
        state_status >= 0 ///
    using ${data}final/acs_working_file, clear

** Keep required years (use earliest start year; filter later in loop)
keep if inrange(year, 2010, `end')

** -----------------------------------------------------------------------------
** KEY SAMPLE RESTRICTION: Keep only individuals with reported hours and weeks
** -----------------------------------------------------------------------------
keep if hours_worked_y_reported == 1 & weeks_worked_y_reported == 1

** Report sample size after restriction
qui count
di as txt "Sample size after restricting to reported hours/weeks: " as res r(N)

** =============================================================================
** Create sample indicators
** =============================================================================

** Medicaid Expansion States
gen medicaid = state_status > 0 & inlist(state_fips, 4, 5, 6, 8, 9, 10, 11, ///
                                         15, 17, 19, 21, 24, ///
                                         25, 26, 27, 32, 33, 34, ///
                                         35, 36, 38, 39, 41, 44, ///
                                         50, 53, 54)

** No EITC States
gen noeitc = state_status > 0 & !inlist(state_fips, 2, 8, 9, 10, 11, 15, ///
                                        17, 18, 19, 23, 24, 25, ///
                                        26, 27, 30, 31, 34, 35, ///
                                        39, 40, 41, 44, 45, 49, ///
                                        50, 51, 55)

** Default sample (no EITC change states)
gen default_sample = state_status > 0

** Create main DID variables
gen ca = state_fips == 6
gen post = year > 2014
gen treated = qc_present == 1 & ca == 1 & post == 1
label var treated "ATE"

** Update adults per HH given sample size issues
replace hh_adult_ct = 3 if hh_adult_ct > 3

** Scale outcomes
foreach out of local outcomes {
    replace `out' = `out' * 100
}

** =============================================================================
** Set up results dataset
** =============================================================================

preserve
clear
set obs 0
gen outcome = ""
gen state_sample = ""
gen edu_sample = ""
gen age_sample = ""
gen pre_period = ""
gen ctrl_demo = .
gen ctrl_unemp = .
gen ctrl_mw = .
gen tau = .
gen se = .
gen ci_lower = .
gen ci_upper = .
gen n_obs = .
gen pre_mean = .
gen significant = .
save "${results}tables/speccurve_reported_results.dta", replace
restore

** =============================================================================
** Run specification loop
** =============================================================================

** Loop over outcomes
foreach out of local outcomes {

    ** Loop over pre-period specifications (1=2012 start, 2=2010 start)
    forvalues pp = 1/2 {

        if `pp' == 1 local pp_start = 2012
        if `pp' == 2 local pp_start = 2010

        if `pp' == 1 local pp_txt "Excl. 2010-11"
        if `pp' == 2 local pp_txt "Incl. 2010-11"

        ** Loop over state samples (1=default, 2=noeitc, 3=medicaid)
        forvalues ss = 1/3 {

            if `ss' == 1 local ss_var "default_sample"
            if `ss' == 2 local ss_var "noeitc"
            if `ss' == 3 local ss_var "medicaid"

            if `ss' == 1 local ss_txt "No EITC Change"
            if `ss' == 2 local ss_txt "No State EITC"
            if `ss' == 3 local ss_txt "Medicaid Expansion"

            ** Loop over education samples (1=low ed, 2=all ed)
            forvalues ed = 1/2 {

                if `ed' == 1 local ed_cond "education < 4"
                if `ed' == 2 local ed_cond "1 == 1"

                if `ed' == 1 local ed_txt "Low Education"
                if `ed' == 2 local ed_txt "All Education"

                ** Loop over age samples (1=20-49, 2=20-64)
                forvalues ag = 1/2 {

                    if `ag' == 1 local ag_cond "inrange(age, 20, 49)"
                    if `ag' == 2 local ag_cond "inrange(age, 20, 64)"

                    if `ag' == 1 local ag_txt "Age 20-49"
                    if `ag' == 2 local ag_txt "Age 20-64"

                    ** Loop over control specifications (0-7 for all combinations)
                    forvalues c = 0/7 {

                        ** Determine which controls to include
                        local c_demo = mod(`c', 2)
                        local c_unemp = mod(floor(`c'/2), 2)
                        local c_mw = mod(floor(`c'/4), 2)

                        ** Build control list
                        local ctrl_list ""
                        if `c_demo' == 1 local ctrl_list "`controls'"

                        local unemp_ctrl ""
                        if `c_unemp' == 1 local unemp_ctrl "c.`unemp'#i.qc_ct"

                        local mw_ctrl ""
                        if `c_mw' == 1 local mw_ctrl "c.`minwage'#i.qc_ct"

                        ** Run regression
                        capture {
                            reghdfe `out' ///
                                treated ///
                                `unemp_ctrl' ///
                                `mw_ctrl' ///
                                if `ss_var' == 1 & `ed_cond' & `ag_cond' & ///
                                   inrange(year, `pp_start', `end') ///
                            [aw = weight], ///
                            absorb(`did_base' `ctrl_list') ///
                            vce(cluster `clustervar')

                            ** Store results
                            local tmp_tau = _b[treated]
                            local tmp_se = _se[treated]
                            local tmp_n = e(N)

                            ** Compute significance (|t| > 1.96)
                            local tmp_sig = abs(`tmp_tau' / `tmp_se') > 1.96

                            ** Get pre-period mean
                            qui summ `out' if ///
                                `ss_var' == 1 & `ed_cond' & `ag_cond' & ///
                                post == 0 & ca == 1 & qc_present == 1 & ///
                                inrange(year, `pp_start', `end') ///
                                [aw = weight]
                            local tmp_mean = r(mean)

                            ** Save to results file
                            preserve
                            clear
                            set obs 1
                            gen outcome = "`out'"
                            gen state_sample = "`ss_txt'"
                            gen edu_sample = "`ed_txt'"
                            gen age_sample = "`ag_txt'"
                            gen pre_period = "`pp_txt'"
                            gen ctrl_demo = `c_demo'
                            gen ctrl_unemp = `c_unemp'
                            gen ctrl_mw = `c_mw'
                            gen tau = `tmp_tau'
                            gen se = `tmp_se'
                            gen ci_lower = `tmp_tau' - 1.96 * `tmp_se'
                            gen ci_upper = `tmp_tau' + 1.96 * `tmp_se'
                            gen n_obs = `tmp_n'
                            gen pre_mean = `tmp_mean'
                            gen significant = `tmp_sig'
                            append using "${results}tables/speccurve_reported_results.dta"
                            save "${results}tables/speccurve_reported_results.dta", replace
                            restore
                        }

                    }

                }

            }

        }

    }

}

** =============================================================================
** Create specification curve plots
** =============================================================================

use "${results}tables/speccurve_reported_results.dta", clear

** Create specification indicators
gen spec_default = state_sample == "No EITC Change"
gen spec_noeitc = state_sample == "No State EITC"
gen spec_medicaid = state_sample == "Medicaid Expansion"
gen spec_lowed = edu_sample == "Low Education"
gen spec_alled = edu_sample == "All Education"
gen spec_age49 = age_sample == "Age 20-49"
gen spec_age64 = age_sample == "Age 20-64"
gen spec_pre_excl = pre_period == "Excl. 2010-11"
gen spec_pre_incl = pre_period == "Incl. 2010-11"

** Loop over outcomes
foreach out in employed_y full_time_y part_time_y {

    ** Get outcome label
    if "`out'" == "employed_y" local out_lbl "Any Employment"
    if "`out'" == "full_time_y" local out_lbl "Full-Time Employment"
    if "`out'" == "part_time_y" local out_lbl "Part-Time Employment"

    ** Preserve full data
    preserve

    ** Keep only relevant outcome
    keep if outcome == "`out'"

    ** Sort by effect size and create rank
    sort tau
    gen spec_rank = _n
    qui count
    local n_specs = r(N)

    ** Create variables for significance-based coloring
    gen tau_sig = tau if significant == 1
    gen tau_insig = tau if significant == 0
    gen ci_lower_sig = ci_lower if significant == 1
    gen ci_upper_sig = ci_upper if significant == 1
    gen ci_lower_insig = ci_lower if significant == 0
    gen ci_upper_insig = ci_upper if significant == 0

    ** Create upper panel: Coefficient plot with CIs colored by significance
    ** Dark blue (navy) for significant, light blue (ltblue) for insignificant
    twoway (rcap ci_lower_sig ci_upper_sig spec_rank, lc(navy) lw(thin)) ///
           (rcap ci_lower_insig ci_upper_insig spec_rank, lc(ltblue) lw(thin)) ///
           (scatter tau_sig spec_rank, mc(navy) ms(O) msize(vsmall)) ///
           (scatter tau_insig spec_rank, mc(ltblue) ms(O) msize(vsmall)), ///
        legend(order(3 "Significant (p<0.05)" 4 "Insignificant") ///
               rows(1) pos(6) size(vsmall)) ///
        ytitle("Treatment Effect (pp), `out_lbl'") ///
        xtitle("") ///
        yline(0, lc(red) lp(dash)) ///
        xlabel(none) ///
        name(coef_`out', replace)

    ** Create lower panel: Specification indicators
    ** State sample indicators
    gen y_default = -1 if spec_default == 1
    gen y_noeitc = -2 if spec_noeitc == 1
    gen y_medicaid = -3 if spec_medicaid == 1
    ** Education sample indicators
    gen y_lowed = -4 if spec_lowed == 1
    gen y_alled = -5 if spec_alled == 1
    ** Age sample indicators
    gen y_age49 = -6 if spec_age49 == 1
    gen y_age64 = -7 if spec_age64 == 1
    ** Pre-period indicators
    gen y_pre_excl = -8 if spec_pre_excl == 1
    gen y_pre_incl = -9 if spec_pre_incl == 1
    ** Control indicators
    gen y_demo = -10 if ctrl_demo == 1
    gen y_unemp = -11 if ctrl_unemp == 1
    gen y_mw = -12 if ctrl_mw == 1

    twoway (scatter y_default spec_rank, mc(navy) ms(O) msize(tiny)) ///
           (scatter y_noeitc spec_rank, mc(navy) ms(O) msize(tiny)) ///
           (scatter y_medicaid spec_rank, mc(navy) ms(O) msize(tiny)) ///
           (scatter y_lowed spec_rank, mc(maroon) ms(O) msize(tiny)) ///
           (scatter y_alled spec_rank, mc(maroon) ms(O) msize(tiny)) ///
           (scatter y_age49 spec_rank, mc(forest_green) ms(O) msize(tiny)) ///
           (scatter y_age64 spec_rank, mc(forest_green) ms(O) msize(tiny)) ///
           (scatter y_pre_excl spec_rank, mc(purple) ms(O) msize(tiny)) ///
           (scatter y_pre_incl spec_rank, mc(purple) ms(O) msize(tiny)) ///
           (scatter y_demo spec_rank, mc(orange) ms(O) msize(tiny)) ///
           (scatter y_unemp spec_rank, mc(orange) ms(O) msize(tiny)) ///
           (scatter y_mw spec_rank, mc(orange) ms(O) msize(tiny)), ///
        legend(off) ///
        ytitle("") ///
        xtitle("Specification (ranked by effect size)") ///
        ylabel(-1 "No EITC Change" ///
               -2 "No State EITC" ///
               -3 "Medicaid Exp." ///
               -4 "Low Education" ///
               -5 "All Education" ///
               -6 "Age 20-49" ///
               -7 "Age 20-64" ///
               -8 "Excl. 2010-11" ///
               -9 "Incl. 2010-11" ///
               -10 "Demographics" ///
               -11 "Unemp. X QC" ///
               -12 "Min Wage X QC", ///
            angle(0) labsize(vsmall)) ///
        xlabel(none) ///
        name(spec_`out', replace)

    ** Combine panels
    graph combine coef_`out' spec_`out', ///
        cols(1) ///
        xcommon ///
        imargin(zero)

    ** Export figure
    graph export "${results}figures/fig_appA_spec_curve_reported_`out'.jpg", ///
        as(jpg) quality(100) replace

    if ${overleaf} == 1 {
        graph export "${ol_fig}fig_appA_spec_curve_reported_`out'.jpg", ///
            as(jpg) quality(100) replace
    }

    ** Clean up
    graph drop coef_`out' spec_`out'

    restore

}

** Also export results as CSV
use "${results}tables/speccurve_reported_results.dta", clear
export delimited "${results}tables/speccurve_reported_results.csv", replace

** =============================================================================
** End
** =============================================================================

clear
log close log_04_appA_fig_spec_curve_rep
