/*******************************************************************************
File Name:      04_appA_fig_unemp_trends.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Appendix A Figure: State Unemployment Trends
                State-level trends in unemployment (2006-2019)

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_fig_unemp_trends
log using "${logs}04_appA_fig_unemp_trends_log_${date}", name(log_04_appA_fig_unemp_trends) replace text

** =============================================================================
** Load pre-processed state unemployment data
** =============================================================================

import delimited using "${data}interim/bls_state_unemployment_monthly.csv", clear

** Keep years 2006-2019
keep if inrange(year, 2006, 2019)

** Tag California vs control states
gen ca = (state_fips == 6)
label var ca "California"
label define lb_ca 0 "Control States" 1 "California"
label values ca lb_ca

** Create monthly date variable for plotting
replace month = subinstr(month, "M", "", .)
destring month, replace
gen date = ym(year, month)
format date %tm

rename value unemp

** =============================================================================
** Collapse for plotting
** =============================================================================

** Collapse by year, month, date, and CA
collapse (mean) unemp 			 ///
         (max) max_unemp = unemp ///
         (min) min_unemp = unemp ///
         (p75) p75_unemp = unemp ///
         (p25) p25_unemp = unemp, ///
         by(year month date ca)

** =============================================================================
** Create Figure: State unemployment trends
** =============================================================================

** Plot
twoway (line unemp date if ca == 1) ///
       (line unemp date if ca == 0) ///
       (line max_unemp date if ca == 0, ///
           lc(gs7) lp(dot)) ///
       (line min_unemp date if ca == 0, ///
           lc(gs7) lp(dot)) ///
       (rarea p75_unemp p25_unemp date if ca == 0, ///
           color(gs7%20) lc(gs7%0))  ///
       legend(pos(6) row(1) order(1 2 3 5) ///
           label(1 "California") ///
           label(2 "Control States Mean") ///
           label(3 "Control States Min / Max") ///
           label(5 "Control States 25th-75th Range")) ///
       ytitle("State Unemployment Rate (%)") ///
       ylab(0(3)15) ///
       ylab(none, nolab notick axis(2)) ///
       yscale(lstyle(none) axis(2)) ///
       xtitle("") ytitle("", axis(2)) ///
       xline(660)

** Save locally
graph export "${results}figures/fig_appA_unemp_trends.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_appA_unemp_trends.jpg", as(jpg) name("Graph") quality(100) replace
}

** END
clear
log close log_04_appA_fig_unemp_trends
