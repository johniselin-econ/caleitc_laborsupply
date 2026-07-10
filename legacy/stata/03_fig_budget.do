/*******************************************************************************
File Name:      03_fig_budget.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Figure 3
                Budget constraint for parent with 2 qualifying children (QC) in 2016

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_budget
log using "${logs}03_fig_budget_log_${date}", name(log_03_fig_budget) replace text

** COLOR PALETTE
local cl_0 "stc1"
local cl_1 "stc2"
local cl_2 "stc3"
local cl_3 "stc6"

** Parameters
local y = 2016  // YEAR
local qc = 2    // QC Count

** Load data (Created by 02_eitc_param_prep.do)
use ${data}interim/eitc_benefit_schedule, clear

** Keep required variables and rename
rename earnings income
rename fed_eitc_`qc' fedeitc
rename cal_eitc_`qc' caleitc
rename tot_eitc_`qc' toteitc

** Generate max wage (Assume 52 weeks per year, 40 hours per week)
gen wage = 50000 / (40 * 52)

** Generate hours worked
gen hours_w = income / wage

** Generate max hours worked
egen max_hours_w = max(hours_w)

** Generate leisure hours
gen hours_l = max_hours_w - hours_w

** Therefore we can get a normalized measure
gen norm_hours = (max_hours_w - income / wage) / max_hours_w
label var norm_hours "Normalized hours of leisure"

** Generate after-tax income inclusive of federal EITC
egen income_fed = rowtotal(income fedeitc)
label var income_fed "Earnings + Federal EITC"

** Generate after-tax income inclusive of federal and state EITC
egen income_tot = rowtotal(income fedeitc caleitc)
label var income_tot "Earnings + Federal EITC + CalEITC"

** Label earnings
label var income "Earnings"

** Find maximum Federal and state EITCs
egen max_fed = max(fedeitc)
egen max_cal = max(caleitc)

** Find maximum benefits
qui summ norm_hours if fedeitc == max_fed
local max_fed = `r(max)'
qui summ norm_hours if caleitc == max_cal
local max_cal = `r(mean)'

** Define point of earning at minimum wage
local mw_ca_2015 = round(9 * 40 * 52, 50)
local mw_ca_2016 = round(10 * 40 * 52, 50)
local mw_ca_2017 = round(10 * 40 * 52, 50)
local mw_ca_2018 = round(11 * 40 * 52, 50)
local mw_ca_2019 = round(12 * 40 * 52, 50)

** Define Minwage Hours
qui summ norm_hours if income == `mw_ca_`y''
local minwage = `r(mean)'

** Define points for area indicators
local a_x = `max_cal' + (1 - `max_cal') / 2
local b_x = `max_fed' + (`max_cal' - `max_fed') / 2

** PLOT (scheme-consistent)
twoway  (line income income_fed income_tot norm_hours, ///
            lc(gs6 `cl_`qc'' `cl_`qc'') ///
            lp(dash solid dash)) ///
        (pcarrowi 32000 `max_cal' 32000 1, ///
            color(stc4) mlwidth(thin)) ///
        (pcarrowi 32000 1 32000 `max_cal', ///
            color(stc4) mlwidth(thin)) ///
        (pcarrowi 34000 `max_fed' 34000 `max_cal', ///
            color(stc4) mlwidth(thin)) ///
        (pcarrowi 34000 `max_cal' 34000 `max_fed', ///
            color(stc4) mlwidth(thin)) ///
        (pcarrowi 36000 `max_fed' 36000 0.4, ///
            color(stc4) mlwidth(thin)), ///
        ytitle("Income + Tax Benefits") ///
        xtitle("Normalized hours of leisure") ///
        legend(order(1 2 3) col(1) ring(0) ///
               position(7) bmargin(large) size(small)) ///
        ylabel(,format(%12.0fc) labsize(small)) ///
        xlabel(,format(%9.1fc) labsize(small)) ///
        text(34000 `a_x' "A", color(stc4)) ///
        text(36000 `b_x' "B", color(stc4)) ///
        text(38000 0.5 "C", color(stc4)) ///
        xline(1, lp(dash_dot) lcolor(gs7)) ///
        text(49000 1 "Not Working " "(nw)", ///
            place(west) size(vsmall)) ///
        xline(`max_fed', lp(dash_dot) lcolor(gs9)) ///
        text(49000 `max_fed' "Federal EITC " "Max ", ///
            place(west) size(vsmall)) ///
        xline(`max_cal', lp(dash_dot) lcolor(gs7)) ///
        text(49000 `max_cal' "CalEITC " "Max " "(pt)", ///
            place(west) size(vsmall)) ///
        xline(`minwage', lp(dash_dot) lcolor(gs7)) ///
        text(49000 `minwage' "At Full-time " "Minimum Wage " "(ft)", ///
            place(west) size(vsmall))

** Save locally
graph export "${results}figures/fig_budget.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_budget.jpg", as(jpg) name("Graph") quality(100) replace
}

** END
clear
log close log_03_fig_budget
