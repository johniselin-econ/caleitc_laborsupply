/*******************************************************************************
File Name:      03_fig_earn_bins.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Figure 10a and 10b
                Effect of the CalEITC on employment by earnings bins

                Fig 10a: California - earnings distribution with EITC schedules
                Fig 10b: Control states - earnings distribution comparison

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_earn_bins
log using "${logs}03_fig_earn_bins_log_${date}", name(log_03_fig_earn_bins) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define income variable
local earn = "incearn_nom"

** Define income text
local inc_text "Real Earned Income Bins"

** Define start and end dates
local start = ${start_year}
local end = ${end_year}

** Minimum wage marks (annual: hourly * 40 hrs * 52 weeks)
local minwage = 11 * 40 * 52

** =============================================================================
** Define EITC parameters (2015)
** =============================================================================

** 2015 Federal EITC parameters (2+ QC)
local fed_mc = 5616
local fed_pi = 0.4
local fed_po = 0.2106
local fed_kink1 = 14040
local fed_kink2 = 18340
local fed_kink3 = 45007

** 2015 CalEITC parameters (2+ QC)
local cal_mc = 2467
local cal_pi = 0.34
local cal_po1 = 0.34
local cal_po2 = 0.03
local cal_kink1 = 7276
local cal_kink2 = 13826
local cal_kink3 = 22300

** =============================================================================
** Load data and define sample
** =============================================================================

** Load ACS data
use weight year qc_present state_fips state_status cpi99 `earn' ///
    female married in_school age citizen_test employed_y education ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        employed_y == 1 & ///
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
** Create treatment indicators
** =============================================================================

** Generate CA indicator
gen ca = (state_fips == 6)
label var ca "California"
label define lb_ca 0 "Control states" 1 "California", modify
label values ca lb_ca

** Generate pre-post indicator
gen post = inrange(year, 2015, 2017)
label var post "Post-period indicator"
label define lb_post 0 "2012-2014" 1 "2015-2017", modify
label values post lb_post

** Update QC label
label var qc_present "Qualifying children indicator"
label define lb_qc_present 0 "No QC" 1 "1+ QC", modify
label values qc_present lb_qc_present

** =============================================================================
** Generate income bins
** =============================================================================

** Generate income bins ($6,000 increments)
egen bin_inc = cut(incearn_real), at(0(6000)60000) icode

** Scale each bin to midpoint
replace bin_inc = bin_inc * 6000 + 3000

** =============================================================================
** Save temporary file for loop
** =============================================================================

tempfile fig_earn_bins_data
save `fig_earn_bins_data'
clear

** =============================================================================
** Create figures: Loop over CA vs control states
** =============================================================================

forvalues i = 0(1)1 {

    ** Define labels for Fig A vs B
    if `i' == 0 local sub "b"
    if `i' == 1 local sub "a"

    ** Load data for this geography
    use if ca == `i' & !missing(bin_inc) using `fig_earn_bins_data', clear

    ** Collapse to binned income X Post X QC level
    gen ct = 1
    collapse (sum) ct [fw = weight], by(post bin_inc qc_present)

    ** Generate percent share within each post X QC cell
    bysort post qc_present: egen total = total(ct)
    gen share = 100 * (ct / total)
    label var share "Share (%)"

    ** Keep required variables
    keep post qc_present share bin_inc

    ** Sort by post, qc, and bins
    sort post qc_present bin_inc

    ** Reshape wide by QC status
    reshape wide share, i(bin_inc post) j(qc_present)

    ** Generate first-difference (with QC less without QC)
    gen share_change = share1 - share0
    label var share_change "First-Difference (With QC less no QC)"

    ** =========================================================================
    ** Create graphs
    ** =========================================================================

    ** For Control states: graph without EITC lines
    if `i' == 0 {

        ** Graph
        twoway  (line share_change bin_inc if post == 0, ///
                    lc(stc1) lp(solid)) ///
                (line share_change bin_inc if post == 1, ///
                    lc(stc1) lp(dash)), ///
            legend(row(1) pos(6) ///
                label(1 "2012-2014") ///
                label(2 "2015-2017")) ///
            xtitle("Mean Value of $6,000 `inc_text'") ///
            xlabel(3000(6000)60000, format(%12.0fc) angle(45)) ///
            ylabel(-3(1)3)

        ** Save locally
        graph export "${results}figures/fig_earn_bins`sub'.jpg", ///
            as(jpg) name("Graph") quality(100) replace

        ** Also save as PNG
        graph export "${results}figures/fig_earn_bins`sub'.png", ///
            as(png) name("Graph") width(2400) height(1600) replace

        ** Save to Overleaf if enabled
        if ${overleaf} == 1 {
            graph export "${ol_fig}fig_earn_bins`sub'.jpg", ///
                as(jpg) name("Graph") quality(100) replace
        }

    }

    ** For California: graph with EITC lines
    else if `i' == 1 {

        ** Graph with EITC schedules overlaid
        twoway ///
            /// PLOT ACTUAL INCOME DISTRIBUTIONS
            (line share_change bin_inc if post == 0, lc(stc1) lp(solid)) ///
            (line share_change bin_inc if post == 1, lc(stc1) lp(dash)) ///
            /// PLOT CALEITC SCHEDULE
            (function y = x * `cal_pi', ///
                range(0 `cal_kink1') yaxis(2) lc(gs7%40) lp(dash)) ///
            (function y = `cal_mc' - (x - `cal_kink1') * `cal_po1', ///
                range(`cal_kink1' `cal_kink2') yaxis(2) lc(gs7%40) lp(dash)) ///
            (function y = `cal_mc' - (`cal_kink2' - `cal_kink1') * `cal_po1' ///
                        - (x - `cal_kink2') * `cal_po2', ///
                range(`cal_kink2' `cal_kink3') yaxis(2) lc(gs7%40) lp(dash)) ///
            /// PLOT FEDERAL EITC SCHEDULE
            (function y = x * `fed_pi', ///
                range(0 `fed_kink1') yaxis(2) lc(gs7%40) lp(solid)) ///
            (function y = `fed_mc', ///
                range(`fed_kink1' `fed_kink2') yaxis(2) lc(gs7%40) lp(solid)) ///
            (function y = `fed_mc' - (x - `fed_kink2') * `fed_po', ///
                range(`fed_kink2' `fed_kink3') yaxis(2) lc(gs7%40) lp(solid)), ///
            /// OPTIONS
            text(1.8 11000 "FedEITC", color(gs7%60) placement(west)) ///
            text(-2.5 18000 "CalEITC", color(gs7%60)) ///
            legend(row(1) pos(6) order(1 2) ///
                label(1 "2012-2014") label(2 "2015-2017")) ///
            xline(`minwage', lc(stc2%20)) ///
            text(2.8 `minwage' "Minimum Wage", color(stc2%60) place(east)) ///
            ylabel(-3(1)3) ///
            ylabel(none, axis(2)) ytitle("", axis(2)) yscale(lstyle(none) axis(2)) ///
            xtitle("Mean Value of $6,000 `inc_text'") ///
            xlabel(3000(6000)60000, format(%12.0fc) angle(45))

        ** Save locally
        graph export "${results}figures/fig_earn_bins`sub'.jpg", ///
            as(jpg) name("Graph") quality(100) replace

        ** Also save as PNG
        graph export "${results}figures/fig_earn_bins`sub'.png", ///
            as(png) name("Graph") width(2400) height(1600) replace

        ** Save to Overleaf if enabled
        if ${overleaf} == 1 {
            graph export "${ol_fig}fig_earn_bins`sub'.jpg", ///
                as(jpg) name("Graph") quality(100) replace
        }

    }

}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_fig_earn_bins
