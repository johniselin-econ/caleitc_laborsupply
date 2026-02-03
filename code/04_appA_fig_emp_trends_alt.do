/*******************************************************************************
File Name:      04_appA_fig_emp_trends_alt.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix Figure: Alternative Full-Time Thresholds
                Full-time and part-time employment trends using alternative
                definitions (31 hours and 39 hours instead of 35 hours).

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_fig_emp_trends_alt
log using "${logs}04_appA_fig_emp_trends_alt_log_${date}", ///
    name(log_04_appA_fig_emp_trends_alt) replace text

** =============================================================================
** PANEL A: 31-Hour Threshold
** =============================================================================

** Load ACS data
use weight part_time_y_31 full_time_y_31 qc_present year education ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status ///
    if  female == 1 & ///
		year >= 2010 & 	///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 ///
    using ${data}final/acs_working_file, clear

** Generate indicator for Rest of Country vs. California
gen us = (state_fips != 6)

** Scale variables
replace part_time_y_31 = part_time_y_31 * 100
replace full_time_y_31 = full_time_y_31 * 100

** Collapse data to state by year by QC level
collapse (mean) part_time_y_31 full_time_y_31 ///
         (semean) part_time_y_31_se = part_time_y_31 ///
                  full_time_y_31_se = full_time_y_31 ///
         [aw = weight], ///
    by(year qc_present us)

** Get CI
foreach v of varlist part_time_y_31 full_time_y_31 {
    gen `v'_u = `v' + 1.96 * `v'_se
    gen `v'_l = `v' - 1.96 * `v'_se
}

** Label variables
label var part_time_y_31 "Percent employed part-time (31hr threshold)"
label var full_time_y_31 "Percent employed full-time (31hr threshold)"
label var qc_present "QC present"
label var us "relative to rest of the US"
label define lb_us 0 "California" 1 "Control States"
label values us lb_us

** Figure: Full-time employment (31-hour threshold)
twoway  (line full_time_y_31 year if qc_present == 0, ///
            lc(stc1)) ///
        (line full_time_y_31 year if qc_present == 1, ///
            lc(stc2)) ///
        (rarea full_time_y_31_u full_time_y_31_l year ///
            if qc_present == 0, ///
            color(stc1%20)) ///
        (rarea full_time_y_31_u full_time_y_31_l year ///
            if qc_present == 1, ///
            color(stc2%20)), ///
    legend(order(1 2) row(1) ///
           label(1 "No qualifying children") ///
           label(2 "1+ qualifying children")) ///
    by(us, legend(position(6)) note("")) ///
    ytitle("Percent employed full-time (31hr threshold)") ///
    xtitle("") ///
    xline(2012, lcolor(gs7%30)) ///
    xline(2015, lcolor(gs7%50)) ///
    xline(2018, lcolor(gs7%30))

** Save locally
graph export "${results}figures/fig_emp_trends_31_a.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_emp_trends_31_a.jpg", as(jpg) name("Graph") quality(100) replace
}

** Figure: Part-time employment (31-hour threshold)
twoway  (line part_time_y_31 year if qc_present == 0, ///
            lc(stc1)) ///
        (line part_time_y_31 year if qc_present == 1, ///
            lc(stc2)) ///
        (rarea part_time_y_31_u part_time_y_31_l year ///
            if qc_present == 0, ///
            color(stc1%20)) ///
        (rarea part_time_y_31_u part_time_y_31_l year ///
            if qc_present == 1, ///
            color(stc2%20)), ///
    legend(order(1 2) row(1) ///
           label(1 "No qualifying children") ///
           label(2 "1+ qualifying children")) ///
    by(us, legend(position(6)) note("")) ///
    ytitle("Percent employed part-time (31hr threshold)") ///
    xtitle("") ///
    xline(2012, lcolor(gs7%30)) ///
    xline(2015, lcolor(gs7%50)) ///
    xline(2018, lcolor(gs7%30))

** Save locally
graph export "${results}figures/fig_emp_trends_31_b.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_emp_trends_31_b.jpg", as(jpg) name("Graph") quality(100) replace
}

** =============================================================================
** PANEL B: 39-Hour Threshold
** =============================================================================

** Load ACS data
use weight part_time_y_39 full_time_y_39 qc_present year education ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status ///
    if  female == 1 & ///
		year >= 2010 & 	///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 ///
    using ${data}final/acs_working_file, clear

** Generate indicator for Rest of Country vs. California
gen us = (state_fips != 6)

** Scale variables
replace part_time_y_39 = part_time_y_39 * 100
replace full_time_y_39 = full_time_y_39 * 100

** Collapse data to state by year by QC level
collapse (mean) part_time_y_39 full_time_y_39 ///
         (semean) part_time_y_39_se = part_time_y_39 ///
                  full_time_y_39_se = full_time_y_39 ///
         [aw = weight], ///
    by(year qc_present us)

** Get CI
foreach v of varlist part_time_y_39 full_time_y_39 {
    gen `v'_u = `v' + 1.96 * `v'_se
    gen `v'_l = `v' - 1.96 * `v'_se
}

** Label variables
label var part_time_y_39 "Percent employed part-time (39hr threshold)"
label var full_time_y_39 "Percent employed full-time (39hr threshold)"
label var qc_present "QC present"
label var us "relative to rest of the US"
label define lb_us 0 "California" 1 "Control States", replace
label values us lb_us

** Figure: Full-time employment (39-hour threshold)
twoway  (line full_time_y_39 year if qc_present == 0, ///
            lc(stc1)) ///
        (line full_time_y_39 year if qc_present == 1, ///
            lc(stc2)) ///
        (rarea full_time_y_39_u full_time_y_39_l year ///
            if qc_present == 0, ///
            color(stc1%20)) ///
        (rarea full_time_y_39_u full_time_y_39_l year ///
            if qc_present == 1, ///
            color(stc2%20)), ///
    legend(order(1 2) row(1) ///
           label(1 "No qualifying children") ///
           label(2 "1+ qualifying children")) ///
    by(us, legend(position(6)) note("")) ///
    ytitle("Percent employed full-time (39hr threshold)") ///
    xtitle("") ///
    xline(2012, lcolor(gs7%30)) ///
    xline(2015, lcolor(gs7%50)) ///
    xline(2018, lcolor(gs7%30))

** Save locally
graph export "${results}figures/fig_emp_trends_39_a.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_emp_trends_39_a.jpg", as(jpg) name("Graph") quality(100) replace
}

** Figure: Part-time employment (39-hour threshold)
twoway  (line part_time_y_39 year if qc_present == 0, ///
            lc(stc1)) ///
        (line part_time_y_39 year if qc_present == 1, ///
            lc(stc2)) ///
        (rarea part_time_y_39_u part_time_y_39_l year ///
            if qc_present == 0, ///
            color(stc1%20)) ///
        (rarea part_time_y_39_u part_time_y_39_l year ///
            if qc_present == 1, ///
            color(stc2%20)), ///
    legend(order(1 2) row(1) ///
           label(1 "No qualifying children") ///
           label(2 "1+ qualifying children")) ///
    by(us, legend(position(6)) note("")) ///
    ytitle("Percent employed part-time (39hr threshold)") ///
    xtitle("") ///
    xline(2012, lcolor(gs7%30)) ///
    xline(2015, lcolor(gs7%50)) ///
    xline(2018, lcolor(gs7%30))

** Save locally
graph export "${results}figures/fig_emp_trends_39_b.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_emp_trends_39_b.jpg", as(jpg) name("Graph") quality(100) replace
}

** END
log close log_04_appA_fig_emp_trends_alt
