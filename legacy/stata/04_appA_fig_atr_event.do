/*******************************************************************************
File Name:      04_appA_fig_atr_event.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Appendix A Figure: After-Tax Rate Event Study
                Triple-difference estimate of the effect of the CalEITC on after-tax rates

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_fig_atr_event
log using "${logs}04_appA_fig_atr_event_log_${date}", name(log_04_appA_fig_atr_event) replace text

** Load data
** Note: Includes all education levels (not restricted to education < 4)
** because ATR at CalEITC kink is defined for all workers
use if female == 1 & ///
       married == 0 & ///
       in_school == 0 & ///
       age_sample_20_49 == 1 & ///
       citizen_test == 1 & ///
       inrange(year, ${start_year}, ${end_year}) ///
    using "${data}final/acs_working_file.dta", clear

** Prepare After-Tax Rate variables
replace taxsim_sim3_atr_st = 1 - taxsim_sim3_atr_st
label var taxsim_sim3_atr_st "After-tax rate at CalEITC Kink Point"

** Define samples

** No State EITC Changes
gen s1 = state_status > 0

** No State EITC changes + Medicaid Expansion
gen s2 = s1 == 1 & inlist(state_fips, 4, 5, 6, 8, 9, 10, 11, ///
                                      15, 17, 19, 21, 24, ///
                                      25, 26, 27, 32, 33, 34, ///
                                      35, 36, 38, 39, 41, 44, ///
                                      50, 53, 54)

** No State EITCs
gen s3 = s1 == 1 & !inlist(state_fips, 2, 8, 9, 10, 11, 15, ///
                                       17, 18, 19, 20, 23, 24, ///
                                       25, 26, 27, 30, 31, 34, ///
                                       36, 39, 40, 41, 44, 45, ///
                                       50, 51, 55)

** Generate triple difference variables
gen ca = state_fips == 6
gen childXyearXca = cond(qc_present == 1 & ca == 1, year, 2014)
gen treated = state_fips == 6 & qc_present == 1 & year >= 2015
label var treated "Treated"

local did "qc_ct year state_fips"
local did "`did' state_fips#year"
local did "`did' state_fips#qc_ct"
local did "`did' year#qc_ct"

** Loop over samples
foreach s of varlist s1 s2 s3 {

    ** Run Event-Study Regression
    eststo est_3D_`s': reghdfe taxsim_sim3_atr_st ///
                           b2014.childXyearXca ///
                           if `s' == 1 ///
                           [aw = weight], ///
                           absorb(`did') ///
                           vce(cluster state_fips)

} // END SAMPLE LOOP

** =============================================================================
** Produce figure
** =============================================================================

** X-Line value
local xline_val = 2015 - ${start_year} + 0.5

** Generate coef labels and values to show
local coef `""'
local keep ""
local start = ${start_year}
local end = ${end_year}

** Loop over years in model
forvalues y = `start'(1)`end' {

    local keep "`keep' `y'.childXyearXca"
    local coef `"`coef' `y'.childXyearXca = "`y'""'

} // END YEAR LOOP

** Plot Figure
coefplot (est_3D_s1, label("No EITC Changes")) ///
         (est_3D_s2, label("Medicaid Expansion + No EITC Changes")) ///
         (est_3D_s3, label("No State EITCs")), ///
    keep(`keep') coeflabels(`coef') msize(medsmall) ///
    ytitle("Effect of the CalEITC on After-Tax Rates") ///
    title("") subtitle("") ///
    legend(pos(6) rows(1) size(small)) ///
    xline(`xline_val', lcolor(gs6)) omitted baselevels ///
    yline(0, lcolor(gs8) lpattern(dash)) ///
    vertical ciopts(recast(rcap)) ///
    ysc(r(0)) ylabel(-0.05(0.05)0.20)

graph export "${results}figures/fig_appA_atr_event.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_appA_atr_event.jpg", as(jpg) name("Graph") quality(100) replace
}

** END
clear
log close log_04_appA_fig_atr_event
