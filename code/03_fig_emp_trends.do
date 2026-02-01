/*******************************************************************************
File Name:      03_fig_emp_trends.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Figure 4a and 4b
                Full-time and part-time employment in the ACS

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_emp_trends
log using "${logs}03_fig_emp_trends_log_${date}", name(log_03_fig_emp_trends) replace text

** Load ACS data
use weight part_time_y full_time_y qc_present year education ///
    female married in_school age citizen_test state_fips state_status ///
    if  female == 1 & ///
		year >= 2010 & 	///
        married == 0 & ///
        in_school == 0 & ///
        inrange(age, 20, 50) & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 ///
    using ${data}final/acs_working_file, clear

** Generate indicator for Rest of Country vs. California
gen us = (state_fips != 6)

** Scale variables
replace part_time_y = part_time_y * 100
replace full_time_y = full_time_y * 100

** Collapse data to state by year by QC level
collapse (mean) part_time_y full_time_y ///
         (semean) part_time_y_se = part_time_y ///
                  full_time_y_se = full_time_y ///
         [aw = weight], ///
    by(year qc_present us)

** Get CI
foreach v of varlist part_time_y full_time_y {
    gen `v'_u = `v' + 1.96 * `v'_se
    gen `v'_l = `v' - 1.96 * `v'_se
}

** Label variables
label var part_time_y "Percent employed part-time in the last 12 months"
label var full_time_y "Percent employed full-time in the last 12 months"
label var qc_present "QC present"
label var us "relative to rest of the US"
label define lb_us 0 "California" 1 "Control States"
label values us lb_us

** Figure 4a: Full-time employment
twoway  (line full_time_y year if qc_present == 0, ///
            lc(stc1)) ///
        (line full_time_y year if qc_present == 1, ///
            lc(stc2)) ///
        (rarea full_time_y_u full_time_y_l year ///
            if qc_present == 0, ///
            color(stc1%20)) ///
        (rarea full_time_y_u full_time_y_l year ///
            if qc_present == 1, ///
            color(stc2%20)), ///
    legend(order(1 2) row(1) ///
           label(1 "No qualifying children") ///
           label(2 "1+ qualifying children")) ///
    by(us, legend(position(6)) note("")) ///
    ytitle("Percent employed full-time") ///
    xtitle("") ///
    xline(2012, lcolor(gs7%30)) ///
    xline(2015, lcolor(gs7%50)) ///
    xline(2018, lcolor(gs7%30))

** Save locally
graph export "${results}figures/fig_emp_trends_a.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_emp_trends_a.jpg", as(jpg) name("Graph") quality(100) replace
}

** Figure 4b: Part-time employment
twoway  (line part_time_y year if qc_present == 0, ///
            lc(stc1)) ///
        (line part_time_y year if qc_present == 1, ///
            lc(stc2)) ///
        (rarea part_time_y_u part_time_y_l year ///
            if qc_present == 0, ///
            color(stc1%20)) ///
        (rarea part_time_y_u part_time_y_l year ///
            if qc_present == 1, ///
            color(stc2%20)), ///
    legend(order(1 2) row(1) ///
           label(1 "No qualifying children") ///
           label(2 "1+ qualifying children")) ///
    by(us, legend(position(6)) note("")) ///
    ytitle("Percent employed part-time") ///
    xtitle("") ///
    xline(2012, lcolor(gs7%30)) ///
    xline(2015, lcolor(gs7%50)) ///
    xline(2018, lcolor(gs7%30))

** Save locally
graph export "${results}figures/fig_emp_trends_b.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_emp_trends_b.jpg", as(jpg) name("Graph") quality(100) replace
}

** END
log close log_03_fig_emp_trends
