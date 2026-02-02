/*******************************************************************************
File Name:      04_appA_fig_minwage.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Appendix A Figure: Minimum Wage Trends
                Binding state minimum wages in control pool (2010-2017)

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_fig_minwage
log using "${logs}04_appA_fig_minwage_log_${date}", name(log_04_appA_fig_minwage) replace text

** =============================================================================
** Load pre-processed state minimum wage data
** =============================================================================

use "${data}interim/st_minwage_year.dta", clear

** Keep in date range (2010-2017)
keep if inrange(year, 2010, 2017)

** Set as panel dataset
encode statename, gen(state)
tsset state year

** =============================================================================
** Create Figure: Binding state minimum wages
** =============================================================================

** PLOT
xtline mean_st_mw , ///
    overlay xtitle("") ytitle("Binding State Minimum Wage (USD)") ///
    legend(pos(6) row(3)) xlabel(, format(%tmCY)) ///
    plot3opts(lc(black) lwidth(medthick))

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
