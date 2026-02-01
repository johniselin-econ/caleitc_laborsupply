/*******************************************************************************
File Name:      03_fig_treat_by_earn.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Figure 11a, 11b, and 11c
                Effect of the CalEITC on employment by earnings bins

                Fig 11a: Employment treatment effects by earnings bin
                Fig 11b: Full-time employment treatment effects by earnings bin
                Fig 11c: Part-time employment treatment effects by earnings bin

                Runs triple-difference regressions within each $6,000 earnings
                bin and plots the treatment coefficients with confidence intervals.

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_treat_by_earn
log using "${logs}03_fig_treat_by_earn_log_${date}", name(log_03_fig_treat_by_earn) replace text

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

** Earnings variable
local earn "incearn_nom"

** Define start and end dates
local start = ${start_year}
local end = ${end_year}

** =============================================================================
** Define fixed effects specification
** =============================================================================

** Full triple-difference specification
local did "qc_ct year state_fips"
local did "`did' state_fips#year"
local did "`did' state_fips#qc_ct"
local did "`did' year#qc_ct"
local unemp_spec "c.`unemp'#i.qc_ct"
local mw_spec "c.`minwage'#i.qc_ct"

** =============================================================================
** Load data and define sample
** =============================================================================

** Load ACS data
use weight `outcomes' `controls' `unemp' `minwage' qc_* year `earn' ///
    female married in_school age citizen_test state_fips state_status cpi99 ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        inrange(age, 20, 50) & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", clear

** =============================================================================
** Real income adjustment (to 2017 dollars)
** =============================================================================

** Generate CPI adjusted values
qui summ cpi99 if year == 2017
local cpi_17 = r(mean)
gen incearn_real = `earn' * (cpi99 / `cpi_17')

** =============================================================================
** Create treatment variables
** =============================================================================

** Create main DID variables
gen ca = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)
label var treated "ATE"

** Update adults per HH given sample size issues
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** Label minimum wage variable
label var mean_st_mw "Binding state minimum wage"

** =============================================================================
** Run regressions and create figures
** =============================================================================

** Clear stored estimates
eststo clear

** Figure parameters
local yaxis_max = 3
local yaxis_cut = 1

** Loop over outcome variables
foreach out of local outcomes {

    ** Define figure suffix
    if "`out'" == "employed_y" local sub "a"
    if "`out'" == "full_time_y" local sub "b"
    if "`out'" == "part_time_y" local sub "c"

    ** Scale outcome to percentage points
    replace `out' = `out' * 100

    ** =========================================================================
    ** Loop over income buckets and run regressions
    ** =========================================================================

    local j = 0
    forvalues i = 1(6000)60001 {

        ** Counter
        local ++j

        ** Generate binned outcome variable
        if `i' == 60001 {
            gen `out'_`j' = `out' == 100 & incearn_real >= `i'
        }
        else {
            gen `out'_`j' = `out' == 100 & inrange(incearn_real, `i', `i' + 5999)
        }
        replace `out'_`j' = 100 * `out'_`j'

        ** Run regression
        eststo `out'_`j': ///
            reghdfe `out'_`j' ///
                treated ///
                `unemp_spec' ///
                `mw_spec' ///
            [aw = weight], ///
            absorb(`did' ///
                   `controls') ///
            vce(cluster `clustervar')

    }

    ** =========================================================================
    ** Create coefficient plot
    ** =========================================================================

    ** CA minimum wage line position (bin 4-5 boundary)
    local minwage_ca = 4.3

    ** Plot results
    coefplot ///
        (`out'_1, aseq("$3K")) ///
        (`out'_2, aseq("$9K")) ///
        (`out'_3, aseq("$15K")) ///
        (`out'_4, aseq("$21K")) ///
        (`out'_5, aseq("$27K")) ///
        (`out'_6, aseq("$33K")) ///
        (`out'_7, aseq("$39K")) ///
        (`out'_8, aseq("$45K")) ///
        (`out'_9, aseq("$51K")) ///
        (`out'_10, aseq("$57K")) ///
        (`out'_11, aseq("$60K+")), ///
        keep(treated) ///
        ytitle("Average Treatment Effect (pp)") ///
        xtitle("Mean Value of $6,000 Earnings Bins") ///
        pstyle(p1) msize(medsmall) ///
        yline(0, lcolor(black) lpattern(dash)) ///
        ylabel(-`yaxis_max'(`yaxis_cut')`yaxis_max') ///
        ciopts(recast(rcap)) ///
        vertical aseq swapnames legend(off) ///
        xline(`minwage_ca') ///
        text(3 `minwage_ca' "CA Minimum Wage (2017)", place(e)) ///
        addplot( ///
            function y = x * 0.338, ///
                range(0 7300) yaxis(2) xaxis(2) ///
                lcolor(black) lpattern(dot) || ///
            function y = 2467 - (x - 7300) * 0.339, ///
                range(7300 13850) yaxis(2) xaxis(2) ///
                lcolor(black) lpattern(dot) || ///
            function y = 246.55 - (x - 13850) * 0.030, ///
                range(13850 22300) yaxis(2) xaxis(2) ///
                lcolor(black) lpattern(dot) || ///
            function y = 0, ///
                range(0 60000) yaxis(2) xaxis(2) ///
                lcolor(none) lpattern(dash)) ///
        ylabel(none, axis(2)) xlabel(none, axis(2)) ///
        ytitle("", axis(2)) xtitle("", axis(2))

    ** Save locally
    graph export "${results}figures/fig_treat_by_earn`sub'.jpg", ///
        as(jpg) name("Graph") quality(100) replace

    ** Also save as PNG
    graph export "${results}figures/fig_treat_by_earn`sub'.png", ///
        as(png) name("Graph") width(2400) height(1600) replace

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        graph export "${ol_fig}fig_treat_by_earn`sub'.jpg", ///
            as(jpg) name("Graph") quality(100) replace
    }

    ** Drop temporary variables
    drop `out'_1-`out'_11

}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_fig_treat_by_earn
