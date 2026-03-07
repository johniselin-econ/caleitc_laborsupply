/*******************************************************************************
File Name:      03_fig_mvpf_dist.do
Creator:        John Iselin
Date Update:    March 2026

Purpose:        Creates Figure: Distribution of MVPF Estimates

                Shows histogram of MVPF estimates across all specifications
                with vertical lines highlighting preferred specifications.

                Includes Oster (2019) bounds one-off check: computes
                bias-adjusted MVPF at Rmax = 1.3x and 2x R-squared.

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_mvpf_dist
log using "${logs}03_fig_mvpf_dist_log_${date}", name(log_03_fig_mvpf_dist) replace text

** =============================================================================
** Load data (created by 02_mvpf.do)
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

** Loop over FT-PT counterfactual income (1=min wage, 2=median, 3=mean)
forvalues i = 1/3 {

    ** Loop over estimation design (0=triple-diff, 1=quad-diff)
    forvalues j = 0/1 {

        ** Get MVPF for this specification
        ** Note: for design=1, spec_u/spec_m are always 0 (absorbed by FEs)
        if `j' == 1 {
            summ mvpf_4 if  spec_d == `spec_d' & ///
                            spec_u == 0 & ///
                            spec_m == 0 & ///
                            contrs == `contrs' & ///
                            hetero == `hetero' & ///
                            sample == `sample' & ///
                            ft_pt_cf == `i' & ///
                            design == `j'
        }
        else {
            summ mvpf_4 if  spec_d == `spec_d' & ///
                            spec_u == `spec_u' & ///
                            spec_m == `spec_m' & ///
                            contrs == `contrs' & ///
                            hetero == `hetero' & ///
                            sample == `sample' & ///
                            ft_pt_cf == `i' & ///
                            design == `j'
        }

        local mvpf_`i'_`j' = `r(mean)'

        dis "MVPF for ft_pt_cf=`i', design=`j': `mvpf_`i'_`j''"

    } // END DESIGN LOOP

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
        legend( label(2 "Triple-Diff, Min Wage CF") ///
                label(3 "Quad-Diff, Min Wage CF") ///
                label(4 "Triple-Diff, Median CF") ///
                label(5 "Quad-Diff, Median CF") ///
                label(6 "Triple-Diff, Mean CF") ///
                label(7 "Quad-Diff, Mean CF") ///
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
** Figure 4: MVPF by Estimation Design (faceted)
** =============================================================================

twoway hist mvpf_4, percent color(gs7%40) by(design, row(1) note("")) ///
    xlab(, format(%9.2fc)) ///
    xtitle("Marginal Value of Public Funds (MVPF)")

graph export "${results}paper/fiscal/fig_mvpf_dist_bydesign.jpg", ///
    as(jpg) quality(100) replace

graph export "${results}paper/fiscal/fig_mvpf_dist_bydesign.png", ///
    as(png) width(2400) height(1600) replace

if ${overleaf} == 1 {
    graph export "${ol_fig}fig_mvpf_dist_bydesign.jpg", ///
        as(jpg) quality(100) replace
}

** =============================================================================
** Summary statistics
** =============================================================================

dis _n _dup(70)"="
dis "MVPF Summary for Preferred Specification"
dis _dup(70)"="
dis "Triple-Diff, Min Wage CF:   `mvpf_1_0'"
dis "Quad-Diff, Min Wage CF:     `mvpf_1_1'"
dis "Triple-Diff, Median CF:     `mvpf_2_0'"
dis "Quad-Diff, Median CF:       `mvpf_2_1'"
dis "Triple-Diff, Mean CF:       `mvpf_3_0'"
dis "Quad-Diff, Mean CF:         `mvpf_3_1'"
dis _dup(70)"="

** Overall summary
summ mvpf_4, de
dis "Overall MVPF: Mean = `r(mean)', SD = `r(sd)', Min = `r(min)', Max = `r(max)'"

** =============================================================================
** Oster (2019) Bounds: One-Off MVPF Sensitivity Check
** =============================================================================

** Compute Oster-adjusted treatment effects and scale MVPF accordingly.
** If unobservables matter proportionally to observables (delta=1), how much
** do the fiscal externalities shrink?

dis _n _dup(70)"="
dis "OSTER (2019) BOUNDS — MVPF SENSITIVITY"
dis _dup(70)"="

** Save current MVPF results
tempfile mvpf_results
save `mvpf_results'

** -------------------------------------------------------------------------
** Step 1: Run Oster regressions on preferred sample
** -------------------------------------------------------------------------

** Load baseline sample (low-ed, 20-49, control + CA)
load_baseline_sample
setup_did_vars

** --- Part-time employment ---

** Restricted model (FEs only, no individual controls)
qui reghdfe part_time_y treated [aw=weight], ///
    absorb($did_base) vce(cluster $clustervar)
local beta_R_pt = _b[treated]
local R2_R_pt = e(r2_a)

** Full model (FEs + all controls)
qui reghdfe part_time_y treated c.$unemp#i.qc_ct c.$minwage#i.qc_ct [aw=weight], ///
    absorb($did_base $controls) vce(cluster $clustervar)
local beta_F_pt = _b[treated]
local R2_F_pt = e(r2_a)

** --- Full-time employment ---

qui reghdfe full_time_y treated [aw=weight], ///
    absorb($did_base) vce(cluster $clustervar)
local beta_R_ft = _b[treated]
local R2_R_ft = e(r2_a)

qui reghdfe full_time_y treated c.$unemp#i.qc_ct c.$minwage#i.qc_ct [aw=weight], ///
    absorb($did_base $controls) vce(cluster $clustervar)
local beta_F_ft = _b[treated]
local R2_F_ft = e(r2_a)

** -------------------------------------------------------------------------
** Step 2: Compute Oster-adjusted betas and scaling ratios
** -------------------------------------------------------------------------

foreach out in pt ft {

    ** Rmax = 1.3 * R2_F (Oster default)
    local Rmax_13_`out' = min(1.3 * `R2_F_`out'', 1)
    ** Rmax = 2 * R2_F (robustness)
    local Rmax_2R_`out' = min(2.0 * `R2_F_`out'', 1)

    ** Oster formula: beta_adj = beta_F - (beta_R - beta_F) * (Rmax - R2_F) / (R2_F - R2_R)
    local R2_diff_`out' = `R2_F_`out'' - `R2_R_`out''

    if abs(`R2_diff_`out'') > 1e-10 {
        local beta_adj_13_`out' = `beta_F_`out'' - ///
            (`beta_R_`out'' - `beta_F_`out'') * ///
            (`Rmax_13_`out'' - `R2_F_`out'') / `R2_diff_`out''

        local beta_adj_2R_`out' = `beta_F_`out'' - ///
            (`beta_R_`out'' - `beta_F_`out'') * ///
            (`Rmax_2R_`out'' - `R2_F_`out'') / `R2_diff_`out''
    }
    else {
        local beta_adj_13_`out' = `beta_F_`out''
        local beta_adj_2R_`out' = `beta_F_`out''
    }

    ** Scaling ratio: how much does the effect shrink?
    if abs(`beta_F_`out'') > 1e-10 {
        local scale_13_`out' = `beta_adj_13_`out'' / `beta_F_`out''
        local scale_2R_`out' = `beta_adj_2R_`out'' / `beta_F_`out''
    }
    else {
        local scale_13_`out' = 1
        local scale_2R_`out' = 1
    }

    dis _n "  `out': beta_R = " %8.5f `beta_R_`out'' ///
           ", beta_F = " %8.5f `beta_F_`out''
    dis "    Rmax=1.3x: beta_adj = " %8.5f `beta_adj_13_`out'' ///
        ", scale = " %6.3f `scale_13_`out''
    dis "    Rmax=2.0x: beta_adj = " %8.5f `beta_adj_2R_`out'' ///
        ", scale = " %6.3f `scale_2R_`out''
}

** Average scaling ratio across PT and FT
** (both outcomes scale the behavioral response that drives fiscal externalities)
local scale_13 = (`scale_13_pt' + `scale_13_ft') / 2
local scale_2R = (`scale_2R_pt' + `scale_2R_ft') / 2

dis _n "  Average scaling ratios:"
dis "    Rmax=1.3x: " %6.3f `scale_13'
dis "    Rmax=2.0x: " %6.3f `scale_2R'

** -------------------------------------------------------------------------
** Step 3: Apply scaling to preferred MVPF
** -------------------------------------------------------------------------

** Reload MVPF results
use `mvpf_results', clear

** Get preferred specification components (triple-diff, min wage CF)
local pref "sample == 1 & spec_d == 1 & spec_u == 1 & spec_m == 1 & contrs == 0 & hetero == 2 & ft_pt_cf == 1 & design == 0"

qui summ direct_costs_real if `pref'
local dc = `r(mean)'

qui summ effect_caleitc_opt3_real if `pref'
local eff_cal = `r(mean)'

qui summ numerator if `pref'
local num_base = `r(mean)'

qui summ denominator_4 if `pref'
local den_base = `r(mean)'

** Fiscal externality = direct_costs - denominator_4
local FE = `dc' - `den_base'

** Baseline MVPF
local mvpf_base = `num_base' / `den_base'

** Oster-adjusted MVPF at Rmax = 1.3x
local num_adj_13 = `dc' - `eff_cal' * `scale_13'
local den_adj_13 = `dc' - `FE' * `scale_13'
local mvpf_oster_13 = `num_adj_13' / `den_adj_13'

** Oster-adjusted MVPF at Rmax = 2x
local num_adj_2R = `dc' - `eff_cal' * `scale_2R'
local den_adj_2R = `dc' - `FE' * `scale_2R'
local mvpf_oster_2R = `num_adj_2R' / `den_adj_2R'

** -------------------------------------------------------------------------
** Step 4: Report results
** -------------------------------------------------------------------------

dis _n _dup(70)"="
dis "OSTER-ADJUSTED MVPF (Preferred Specification, Min Wage CF)"
dis _dup(70)"="
dis "  Baseline MVPF:           " %6.3f `mvpf_base'
dis "  Oster MVPF (Rmax=1.3x): " %6.3f `mvpf_oster_13'
dis "  Oster MVPF (Rmax=2.0x): " %6.3f `mvpf_oster_2R'
dis _n "  Fiscal externality scaling:"
dis "    Baseline FE ($M):      " %9.1f `FE'
dis "    Oster FE, 1.3x ($M):  " %9.1f (`FE' * `scale_13')
dis "    Oster FE, 2.0x ($M):  " %9.1f (`FE' * `scale_2R')
dis _dup(70)"="

** Also check with median CF (ft_pt_cf == 2)
local pref2 "sample == 1 & spec_d == 1 & spec_u == 1 & spec_m == 1 & contrs == 0 & hetero == 2 & ft_pt_cf == 2 & design == 0"

qui summ direct_costs_real if `pref2'
local dc2 = `r(mean)'

qui summ effect_caleitc_opt3_real if `pref2'
local eff_cal2 = `r(mean)'

qui summ denominator_4 if `pref2'
local den_base2 = `r(mean)'

qui summ numerator if `pref2'
local num_base2 = `r(mean)'

local FE2 = `dc2' - `den_base2'
local mvpf_base2 = `num_base2' / `den_base2'
local mvpf_oster_13_med = (`dc2' - `eff_cal2' * `scale_13') / (`dc2' - `FE2' * `scale_13')
local mvpf_oster_2R_med = (`dc2' - `eff_cal2' * `scale_2R') / (`dc2' - `FE2' * `scale_2R')

dis _n "OSTER-ADJUSTED MVPF (Preferred Specification, Median CF)"
dis _dup(70)"-"
dis "  Baseline MVPF:           " %6.3f `mvpf_base2'
dis "  Oster MVPF (Rmax=1.3x): " %6.3f `mvpf_oster_13_med'
dis "  Oster MVPF (Rmax=2.0x): " %6.3f `mvpf_oster_2R_med'
dis _dup(70)"="

** =============================================================================
** End
** =============================================================================

clear
log close log_03_fig_mvpf_dist
