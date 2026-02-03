/*******************************************************************************
File Name:      04_appA_fig_minwage.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Appendix A Figure: Minimum Wage Trends
                Binding state minimum wages in control pool (monthly, 2010-2017)
                Includes NBER recession shading

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_fig_minwage
log using "${logs}04_appA_fig_minwage_log_${date}", name(log_04_appA_fig_minwage) replace text

** =============================================================================
** Load and prepare NBER recession indicator data
** =============================================================================

** Load recession data
import delimited using "${data}raw/USREC.csv", clear

** Parse date and create Stata monthly date
gen year = real(substr(observation_date, 1, 4))
gen month = real(substr(observation_date, 6, 2))
gen date = ym(year, month)
format date %tm

** Keep relevant years
keep if inrange(year, 2010, 2017)

** Keep only recession indicator and date
keep date usrec
rename usrec recession

** Save recession data
tempfile recession_data
save `recession_data', replace

** =============================================================================
** Load pre-processed state minimum wage data (monthly)
** =============================================================================

import delimited using "${data}interim/VKZ_state_minwage_monthly.csv", clear

** Keep in date range (2010-2017)
keep if inrange(year, 2010, 2017)

** Tag California vs control states
gen ca = (state_fips == 6)
label var ca "California"
label define lb_ca 0 "Control States" 1 "California"
label values ca lb_ca

** Create monthly date variable for plotting
gen date = ym(year, month)
format date %tm

** =============================================================================
** Collapse for plotting
** =============================================================================

** Collapse by year, month, date, and CA
collapse (mean) state_minwage 			   ///
         (max) max_minwage = state_minwage ///
         (min) min_minwage = state_minwage ///
         (p75) p75_minwage = state_minwage ///
         (p25) p25_minwage = state_minwage, ///
         by(year month date ca)

** Merge recession indicator
merge m:1 date using `recession_data', keep(master match) nogen

** Get y-axis range for recession shading
qui sum max_minwage
local ymax = ceil(r(max)) + 1
qui sum min_minwage
local ymin = floor(r(min)) - 0.5

** Create recession band (for shading)
gen recession_band = recession * `ymax'
replace recession_band = `ymin' if recession == 0

** =============================================================================
** Create Figure: Binding state minimum wages with recession shading
** =============================================================================

** Plot
twoway (area recession_band date, color(gs14) base(`ymin')) ///
       (line state_minwage date if ca == 1, lc(navy)) ///
       (line state_minwage date if ca == 0, lc(maroon)) ///
       (line max_minwage date if ca == 0, ///
           lc(gs7) lp(dot)) ///
       (line min_minwage date if ca == 0, ///
           lc(gs7) lp(dot)) ///
       (rarea p75_minwage p25_minwage date if ca == 0, ///
           color(gs7%20) lc(gs7%0)), ///
       legend(pos(6) row(1) order(2 3 4 6) ///
           label(2 "California") ///
           label(3 "Control States Mean") ///
           label(4 "Control States Min / Max") ///
           label(6 "Control States 25th-75th Range")) ///
       ytitle("Binding State Minimum Wage (USD)") ///
       ylab(, format(%9.2f)) ///
       xtitle("") ///
       xline(660) ///
       note("Shaded areas indicate NBER recession periods.")

** Save locally
graph export "${results}figures/fig_appA_minwage.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_appA_minwage.jpg", as(jpg) name("Graph") quality(100) replace
}

** END
clear
log close log_04_appA_fig_minwage
