/*******************************************************************************
File Name:      03_fig_hours_bins.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Figure: Effect of the CalEITC on Employment by Hours
                Worked Per Week

                Estimates triple-difference effects across bins of usual hours
                worked per week, showing how the employment effect varies by
                labor supply intensity.

                Uses utility programs: load_baseline_sample, setup_did_vars,
                export_graph

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_hours_bins
log using "${logs}03_fig_hours_bins_log_${date}", name(log_03_fig_hours_bins) replace text

** =============================================================================
** Load data and setup
** =============================================================================

** Load baseline sample with hours variable
load_baseline_sample, varlist(hours_worked_y)

** Create DID variables using utility
setup_did_vars

** =============================================================================
** Define hours worked per week bins
** =============================================================================

** Create hours groups (usual hours worked per week)
gen hours_grp = .
replace hours_grp = 1 if inrange(hours_worked_y, 1, 10)
replace hours_grp = 2 if inrange(hours_worked_y, 11, 19)
replace hours_grp = 3 if inrange(hours_worked_y, 20, 24)
replace hours_grp = 4 if inrange(hours_worked_y, 25, 29)
replace hours_grp = 5 if inrange(hours_worked_y, 30, 34)
replace hours_grp = 6 if inrange(hours_worked_y, 35, 39)
replace hours_grp = 7 if inrange(hours_worked_y, 40, 44)
replace hours_grp = 8 if inrange(hours_worked_y, 45, 49)
replace hours_grp = 9 if inrange(hours_worked_y, 50, 59)
replace hours_grp = 10 if hours_worked_y >= 60 & !missing(hours_worked_y)

** Define bin labels for plotting
local bin_labels `" "1-10" "11-19" "20-24" "25-29" "30-34" "35-39" "40-44" "45-49" "50-59" "60+" "'

** =============================================================================
** Run regressions by hours bin
** =============================================================================

** Clear stored estimates
eststo clear

** Build specification components
local unemp_spec "c.$unemp#i.qc_ct"
local mw_spec "c.$minwage#i.qc_ct"

** Loop over hours bins
local j = 0
levelsof hours_grp, local(vals)

foreach i of local vals {

    ** Counter
    local ++j

    ** Generate binned employment variable
    ** = 1 if employed AND in this hours bin, 0 otherwise
    gen employed_bin_`j' = (employed_y == 1 & hours_grp == `i')
    replace employed_bin_`j' = employed_bin_`j' * 100  // Scale to percentage points

    ** Run triple-difference regression
    eststo est_hours_`j': ///
        reghdfe employed_bin_`j' ///
            treated ///
            `unemp_spec' ///
            `mw_spec' ///
            [aw = weight], ///
        absorb($did_base $controls) ///
        vce(cluster $clustervar)

    ** Store coefficient and SE for reference
    local b_`j' = _b[treated]
    local se_`j' = _se[treated]

    ** Clean up
    drop employed_bin_`j'

}

** =============================================================================
** Create coefficient plot
** =============================================================================

** Plot results (scheme-consistent formatting)
coefplot ///
    (est_hours_1, aseq("1-10")) ///
    (est_hours_2, aseq("11-19")) ///
    (est_hours_3, aseq("20-24")) ///
    (est_hours_4, aseq("25-29")) ///
    (est_hours_5, aseq("30-34")) ///
    (est_hours_6, aseq("35-39")) ///
    (est_hours_7, aseq("40-44")) ///
    (est_hours_8, aseq("45-49")) ///
    (est_hours_9, aseq("50-59")) ///
    (est_hours_10, aseq("60+")), ///
    keep(treated) ///
    ytitle("Average Treatment Effect (pp)") ///
    xtitle("Hours worked per week last year (bins)") ///
    title("") subtitle("") ///
    pstyle(p1) msize(medsmall) ///
    yline(0, lcolor(gs8) lpattern(dash)) ///
    ciopts(recast(rcap)) ///
    vertical aseq swapnames legend(off)

** Export graph using utility
export_graph, filename("fig_hours_bins")

** =============================================================================
** Export coefficients for reference
** =============================================================================

preserve
    clear
    set obs 10

    gen hours_bin = ""
    gen coef = .
    gen se = .
    gen ci_lo = .
    gen ci_hi = .
    gen bin_order = _n

    ** Populate with results
    local bin_names "1-10 11-19 20-24 25-29 30-34 35-39 40-44 45-49 50-59 60+"
    local j = 0
    foreach b of local bin_names {
        local ++j
        qui replace hours_bin = "`b'" in `j'
        qui replace coef = `b_`j'' in `j'
        qui replace se = `se_`j'' in `j'
        qui replace ci_lo = `b_`j'' - 1.96 * `se_`j'' in `j'
        qui replace ci_hi = `b_`j'' + 1.96 * `se_`j'' in `j'
    }

    export delimited "${results}tables/fig_hours_bins_coefficients.csv", replace
restore

** =============================================================================
** Display summary of results
** =============================================================================

di _n "Effect of CalEITC on Employment by Hours Bin:"
di "================================================"
di _col(5) "Hours Bin" _col(20) "Coef" _col(30) "SE" _col(40) "95% CI"
di "------------------------------------------------"

local bin_names "1-10 11-19 20-24 25-29 30-34 35-39 40-44 45-49 50-59 60+"
local j = 0
foreach b of local bin_names {
    local ++j
    local ci_lo = `b_`j'' - 1.96 * `se_`j''
    local ci_hi = `b_`j'' + 1.96 * `se_`j''
    di _col(5) "`b'" _col(18) %7.3f `b_`j'' _col(28) %7.3f `se_`j'' ///
       _col(38) "[" %6.3f `ci_lo' ", " %6.3f `ci_hi' "]"
}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_fig_hours_bins
