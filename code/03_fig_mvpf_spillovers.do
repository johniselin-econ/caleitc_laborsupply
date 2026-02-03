/*******************************************************************************
File Name:      03_fig_mvpf_spillovers.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Figure: Implied Fiscal Spillovers of the CalEITC

                Shows bar chart of fiscal externalities (federal IIT, payroll,
                state IIT) under different labor supply assumptions.

                Based on template 03_fig13.do

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_mvpf_spillovers
log using "${logs}03_fig_mvpf_spillovers_log_${date}", name(log_03_fig_mvpf_spillovers) replace text

** =============================================================================
** Define baseline parameters
** =============================================================================

local spec_d = 1    // With Demographic Controls
local spec_u = 1    // With Unemployment X QC Controls
local spec_m = 1    // With Minimum Wage X QC Controls
local contrs = 0    // Control pool (all states without EITC changes)
local hetero = 2    // Heterogeneity by count of QC
local sample = 1    // Low education sample
local ft_pt_cf = 2  // $27,000 counterfactual FT income

** =============================================================================
** Load and prepare data (created by 03_mvpf.do)
** =============================================================================

use "${data}interim/acs_fiscal_cost_collapse.dta", clear

** Keep preferred specification
keep if spec_d == `spec_d'
keep if spec_u == `spec_u'
keep if spec_m == `spec_m'
keep if contrs == `contrs'
keep if hetero == `hetero'
keep if sample == `sample'
keep if ft_pt_cf == `ft_pt_cf'

** Keep required variables
keep full effect_*
drop effect_caleitc_*

** Rename for reshape
rename effect*_opt*_real effect*_real_opt*

** Reshape to long format (one row per option)
reshape long    effect_fed_liab_real_opt effect_st_liab_real_opt ///
                effect_pay_liab_real_opt effect_fedeitc_real_opt ///
                effect_ctc_real_opt effect_st_nocal_liab_real_opt, ///
                i(full) j(option)

** Clean up variable names
rename *_opt *

** =============================================================================
** Label variables
** =============================================================================

label var effect_fed_liab_real "Federal IIT"
label var effect_pay_liab_real "Federal Payroll Tax"
label var effect_st_nocal_liab_real "State IIT (less CalEITC)"
label var effect_ctc_real "Federal CTC"
label var effect_fedeitc_real "Federal EITC"

label var option "Labor Supply Response"
label define lb_opt 1 "Non-work to part-time only" ///
                    2 "Full-time to part-time only" ///
                    3 "Observed effect", modify
label values option lb_opt

** Flip sign for credits (government expenditure, not revenue)
replace effect_fedeitc_real = effect_fedeitc_real * -1
replace effect_ctc_real = effect_ctc_real * -1

** =============================================================================
** Create combined model variable
** =============================================================================

** Keep relevant combinations:
** - full == 0: All three options (entire FT effect)
** - full == 1: Only option 3 (discrete FT effect)
keep if (full == 0) | (full == 1 & option == 3)

** Sort and create model number
sort full option
gen mod = _n

** Label model categories
label var mod "Labor Supply Responses"
label define lb_mod     1 "Non-work to part-time only" ///
                        2 "Full-time to part-time only" ///
                        3 "Entire Full-time Effect" ///
                        4 "Discrete FT Effect ($24K-$30K)", modify
label values mod lb_mod

** =============================================================================
** Figure 1: Change in Government Revenue
** =============================================================================

graph bar (asis)    effect_fed_liab_real ///
                    effect_pay_liab_real ///
                    effect_st_nocal_liab_real, ///
    over(mod, label(labsize(vsmall))) ///
    ylabel(, format(%12.0fc)) ///
    legend( label(1 "Federal IIT") ///
            label(2 "Federal Payroll Tax") ///
            label(3 "State IIT (less CalEITC)") ///
            row(1) pos(6) size(small)) ///
    ytitle("Change in government revenue (Mil, 2017 USD)")

** Save figures
graph export "${results}paper/fiscal/fig_mvpf_spillovers_revenue.jpg", ///
    as(jpg) quality(100) replace

graph export "${results}paper/fiscal/fig_mvpf_spillovers_revenue.png", ///
    as(png) width(2400) height(1600) replace

** Save to overleaf if enabled
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_mvpf_spillovers_revenue.jpg", ///
        as(jpg) quality(100) replace
}

** =============================================================================
** Figure 2: Change in Tax Credits
** =============================================================================

graph bar (asis)    effect_ctc_real ///
                    effect_fedeitc_real, ///
    over(mod, label(labsize(vsmall))) stack ///
    ylabel(, format(%12.0fc)) ///
    legend( label(1 "Federal CTC") ///
            label(2 "Federal EITC") ///
            row(1) pos(6) size(small)) ///
    ytitle("Change in government expenditure (Mil, 2017 USD)")

** Save figures
graph export "${results}paper/fiscal/fig_mvpf_spillovers_credits.jpg", ///
    as(jpg) quality(100) replace

graph export "${results}paper/fiscal/fig_mvpf_spillovers_credits.png", ///
    as(png) width(2400) height(1600) replace

** Save to overleaf if enabled
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_mvpf_spillovers_credits.jpg", ///
        as(jpg) quality(100) replace
}

** =============================================================================
** Figure 3: All Fiscal Components Combined
** =============================================================================

graph bar (asis)    effect_fed_liab_real ///
                    effect_pay_liab_real ///
                    effect_st_nocal_liab_real ///
                    effect_ctc_real ///
                    effect_fedeitc_real, ///
    over(mod, label(labsize(vsmall))) ///
    ylabel(, format(%12.0fc)) ///
    legend( label(1 "Federal IIT") ///
            label(2 "Payroll Tax") ///
            label(3 "State IIT") ///
            label(4 "Federal CTC") ///
            label(5 "Federal EITC") ///
            row(2) pos(6) size(small)) ///
    ytitle("Change in fiscal position (Mil, 2017 USD)")

** Save figures
graph export "${results}paper/fiscal/fig_mvpf_spillovers_all.jpg", ///
    as(jpg) quality(100) replace

graph export "${results}paper/fiscal/fig_mvpf_spillovers_all.png", ///
    as(png) width(2400) height(1600) replace

** Save to overleaf if enabled
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_mvpf_spillovers_all.jpg", ///
        as(jpg) quality(100) replace
}

** =============================================================================
** Display summary statistics
** =============================================================================

dis _n _dup(70)"="
dis "Fiscal Spillovers Summary (Preferred Specification)"
dis _dup(70)"="
list mod effect_fed_liab_real effect_pay_liab_real effect_st_nocal_liab_real ///
     effect_ctc_real effect_fedeitc_real, clean noobs

** =============================================================================
** End
** =============================================================================

clear
log close log_03_fig_mvpf_spillovers
