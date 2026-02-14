/*******************************************************************************
File Name:      03_fig_mvpf_dist.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Figure: Distribution of MVPF Estimates

                Shows histogram of MVPF estimates across all specifications
                with vertical lines highlighting preferred specifications.

                Based on template 03_fig12.do

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_mvpf_dist
log using "${logs}03_fig_mvpf_dist_log_${date}", name(log_03_fig_mvpf_dist) replace text

** =============================================================================
** Load data (created by 03_mvpf.do)
** =============================================================================

use if p_end == ${end_year} using "${data}interim/acs_fiscal_cost_collapse.dta", clear

** =============================================================================
** Define baseline parameters for preferred specification
** =============================================================================

local spec_d = 1    // With Demographic Controls
local spec_u = 1    // With Unemployment X QC Controls
local spec_m = 1    // With Minimum Wage X QC Controls
local contrs = 0    // Control pool (all states without EITC changes)
local hetero = 2    // Heterogeneity by count of QC
local sample = 1    // Low education sample

label define lb_ft_pt_cf 1 "Binding minimum wage" 2 "Median income" 3 "Mean income", modify
label values ft_pt_cf lb_ft_pt_cf

** =============================================================================
** Calculate MVPF for specific specification combinations
** =============================================================================

** Loop over FT-PT counterfactual income (1=min wage, 2=$27K)
forvalues i = 1/3 {

    ** Loop over full-time effect specification (0=entire, 1=discrete only)
    forvalues j = 0/1 {

        ** Get MVPF for this specification
        summ mvpf_4 if  spec_d == `spec_d' & ///
                        spec_u == `spec_u' & ///
                        spec_m == `spec_m' & ///
                        contrs == `contrs' & ///
                        hetero == `hetero' & ///
                        sample == `sample' & ///
                        ft_pt_cf == `i' & ///
                        full == `j'

        local mvpf_`i'_`j' = `r(mean)'

        dis "MVPF for ft_pt_cf=`i', full=`j': `mvpf_`i'_`j''"

    } // END FULL-TIME EFFECT LOOP

} // END FT-PT COUNTERFACTUAL LOOP

** =============================================================================
** Figure 1: Main MVPF Distribution with Specification Markers
** =============================================================================

** Get histogram range for y-axis
qui summ mvpf_4
local xmin = floor(`r(min)' * 20) / 20
local xmax = ceil(`r(max)' * 20) / 20

** Plot histogram with vertical lines for preferred specifications
twoway  (hist mvpf_4, percent color(gs7%40) bin(20)) ///
        (scatteri 0 `mvpf_1_0' 30 `mvpf_1_0', c(l) m(i) lp(solid) lc(stc1)) ///
        (scatteri 0 `mvpf_1_1' 30 `mvpf_1_1', c(l) m(i) lp(dash) lc(stc1)) ///
        (scatteri 0 `mvpf_2_0' 30 `mvpf_2_0', c(l) m(i) lp(solid) lc(stc2)) ///
        (scatteri 0 `mvpf_2_1' 30 `mvpf_2_1', c(l) m(i) lp(dash) lc(stc2)) ///
        (scatteri 0 `mvpf_3_0' 30 `mvpf_3_0', c(l) m(i) lp(solid) lc(stc3)) ///
        (scatteri 0 `mvpf_3_1' 30 `mvpf_3_1', c(l) m(i) lp(dash) lc(stc3)), ///
        xlab(`xmin'(0.05)`xmax', format(%9.2fc)) ///
        ytitle("Percent of estimates (%)") ///
        xtitle("Marginal Value of Public Funds (MVPF)") ///
        legend( label(2 "Entire FT, Min Wage CF") ///
                label(3 "Discrete FT, Min Wage CF") ///
                label(4 "Entire FT, Median CF") ///
                label(5 "Discrete FT, Median CF") ///
				label(6 "Entire FT, Mean CF") ///
                label(7 "Discrete FT, Mean CF") ///
                order(2 4 6 3 5 7) row(2) pos(6) size(small))

** Save figures
graph export "${results}paper/fiscal/fig_mvpf_distribution.jpg", ///
    as(jpg) quality(100) replace

graph export "${results}paper/fiscal/fig_mvpf_distribution.png", ///
    as(png) width(2400) height(1600) replace

** Save to overleaf if enabled
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_mvpf_distribution.jpg", ///
        as(jpg) quality(100) replace
}

** =============================================================================
** Figure 2: MVPF Distribution by Sample Type
** =============================================================================

twoway  (hist mvpf_4 if sample == 0, percent color(stc1%30) bin(15)) ///
        (hist mvpf_4 if sample == 1, percent color(stc2%30) bin(15)) ///
        (hist mvpf_4 if sample == 2, percent color(stc3%30) bin(15)) ///
        (hist mvpf_4 if sample == 3, percent color(stc4%30) bin(15)), ///
        xlab(, format(%9.2fc)) ///
        ytitle("Percent of estimates (%)") ///
        xtitle("Marginal Value of Public Funds (MVPF)") ///
        legend( label(1 "All") ///
                label(2 "Low Education") ///
                label(3 "Age 20-49") ///
                label(4 "Age 20-64") ///
                row(1) pos(6) size(small))

** Save figures
graph export "${results}paper/fiscal/fig_mvpf_dist_bysample.jpg", ///
    as(jpg) quality(100) replace

graph export "${results}paper/fiscal/fig_mvpf_dist_bysample.png", ///
    as(png) width(2400) height(1600) replace

if ${overleaf} == 1 {
    graph export "${ol_fig}fig_mvpf_dist_bysample.jpg", ///
        as(jpg) quality(100) replace
}

** =============================================================================
** Figure 3: MVPF by Control States (faceted)
** =============================================================================

twoway hist mvpf_4, percent color(gs7%40) by(contrs, row(2) note("")) ///
    xlab(, format(%9.2fc)) ///
    xtitle("Marginal Value of Public Funds (MVPF)")

graph export "${results}paper/fiscal/fig_mvpf_dist_bycontrs.jpg", ///
    as(jpg) quality(100) replace

graph export "${results}paper/fiscal/fig_mvpf_dist_bycontrs.png", ///
    as(png) width(2400) height(1600) replace

if ${overleaf} == 1 {
    graph export "${ol_fig}fig_mvpf_dist_bycontrs.jpg", ///
        as(jpg) quality(100) replace
}

** =============================================================================
** Figure 4: MVPF by Heterogeneity Option (faceted)
** =============================================================================

twoway hist mvpf_4, percent color(gs7%40) by(hetero, row(1) note("")) ///
    xlab(, format(%9.2fc)) ///
    xtitle("Marginal Value of Public Funds (MVPF)")

graph export "${results}paper/fiscal/fig_mvpf_dist_byhetero.jpg", ///
    as(jpg) quality(100) replace

graph export "${results}paper/fiscal/fig_mvpf_dist_byhetero.png", ///
    as(png) width(2400) height(1600) replace

if ${overleaf} == 1 {
    graph export "${ol_fig}fig_mvpf_dist_byhetero.jpg", ///
        as(jpg) quality(100) replace
}

** =============================================================================
** Summary statistics
** =============================================================================

dis _n _dup(70)"="
dis "MVPF Summary for Preferred Specification"
dis _dup(70)"="
dis "FT CF = Min Wage, Entire Effect:   `mvpf_1_0'"
dis "FT CF = Min Wage, Discrete Effect: `mvpf_1_1'"
dis "FT CF = Median Income, Entire Effect:       `mvpf_2_0'"
dis "FT CF = Median Income, Discrete Effect:     `mvpf_2_1'"
dis "FT CF = Mean Income, Entire Effect:       `mvpf_2_0'"
dis "FT CF = Mean Income, Discrete Effect:     `mvpf_2_1'"
dis _dup(70)"="

** Overall summary
summ mvpf_4, de 
dis "Overall MVPF: Mean = `r(mean)', SD = `r(sd)', Min = `r(min)', Max = `r(max)'"

** =============================================================================
** End
** =============================================================================

clear
log close log_03_fig_mvpf_dist
