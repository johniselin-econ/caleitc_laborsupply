/*******************************************************************************
File Name:      03_fig_weeks.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Figure: Employment by Weeks Worked
                Effect of the CalEITC on employment, by annual weeks of work

                Shows treatment effects for:
                - Any Employment
                - Full-Time
                - Part-Time

                Across weeks worked bins: 1-13, 14-26, 27-39, 40-47, 48-49, 50-52

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_weeks
log using "${logs}03_fig_weeks_log_${date}", name(log_03_fig_weeks) replace text

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

** Define start and end dates
local start = ${start_year}
local end = ${end_year}

** SPECIFICATION (Fixed Effects)
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
use weight `outcomes' `controls' `unemp' `minwage' qc_* year weeks_worked_y ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", clear

** Create main DID variables
gen ca = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)
label var treated "ATE"

** Update adults per HH (cap at 3)
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** Label minimum wage variable
label var mean_st_mw "Binding state minimum wage"

** =============================================================================
** Run regressions by outcome and weeks-worked bin
** =============================================================================

** Loop over outcome variables
foreach out of local outcomes {

    ** Subscript for file naming
    if "`out'" == "employed_y" local sub "a"
    if "`out'" == "full_time_y" local sub "b"
    if "`out'" == "part_time_y" local sub "c"

    ** Scale outcome to percentage points
    replace `out' = `out' * 100

    ** Loop over weeks-worked buckets
    local j = 0
    levelsof weeks_worked_y, local(weeks)
    foreach i of local weeks {


        ** Generate binned employment variable
        ** = 100 if employed in this outcome AND in this weeks bucket, 0 otherwise
        gen `out'_`j' = 100 * (`out' == 100 & weeks_worked_y == `i')

        ** Run regression
        eststo est_`out'_`j': ///
            reghdfe `out'_`j' ///
                treated ///
                `unemp_spec' ///
                `mw_spec' ///
                [aw = weight], ///
            absorb(`did' `controls') ///
            vce(cluster `clustervar')

        drop `out'_`j'
		
		        ** Counter
        local ++j


    }

    ** Create individual coefplot for this outcome (scheme-consistent)
    coefplot ///
        (est_`out'_1, aseq("1-13")) ///
        (est_`out'_2, aseq("14-26")) ///
        (est_`out'_3, aseq("27-39")) ///
        (est_`out'_4, aseq("40-47")) ///
        (est_`out'_5, aseq("48-49")) ///
        (est_`out'_6, aseq("50-52")), ///
        keep(treated) ///
        ytitle("Average Treatment Effect (pp)") ///
        xtitle("Weeks worked per year (bins)") ///
        pstyle(p1) msize(small) ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        ciopts(recast(rcap)) ylabel(-4(2)4, labsize(small)) ///
        xlabel(, labsize(small)) ///
        vertical aseq swapnames legend(off)

    ** Save individual figure locally
    graph export "${results}figures/fig_weeks_`sub'.jpg", ///
        as(jpg) name("Graph") quality(100) replace

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        graph export "${ol_fig}fig_weeks_`sub'.jpg", as(jpg) name("Graph") quality(100) replace
    }

}

** =============================================================================
** Create combined figure with all three outcomes
** =============================================================================

** Build coefficient dataset for combined plot
preserve
    clear
    set obs 18
    gen outcome = ""
    gen bin = .
    gen bin_label = ""
    gen coef = .
    gen se = .
    gen ci_lo = .
    gen ci_hi = .

    ** Bin labels
    local bin_labels `" "1-13" "14-26" "27-39" "40-47" "48-49" "50-52" "'

    ** Fill in data
    local row = 1
    foreach out in employed_y full_time_y part_time_y {
        forvalues j = 1/6 {

            ** Get stored estimates
            qui est restore est_`out'_`j'
            local b = _b[treated]
            local s = _se[treated]

            ** Fill row
            qui replace outcome = "`out'" in `row'
            qui replace bin = `j' in `row'

            ** Get bin label
            local lbl : word `j' of `bin_labels'
            qui replace bin_label = "`lbl'" in `row'

            qui replace coef = `b' in `row'
            qui replace se = `s' in `row'
            qui replace ci_lo = `b' - 1.96 * `s' in `row'
            qui replace ci_hi = `b' + 1.96 * `s' in `row'

            local row = `row' + 1
        }
    }

    ** Create numeric x positions with offsets for each outcome
    gen xpos = bin
    replace xpos = xpos - 0.2 if outcome == "employed_y"
    replace xpos = xpos       if outcome == "full_time_y"
    replace xpos = xpos + 0.2 if outcome == "part_time_y"

    ** Plot combined figure (scheme-consistent)
    twoway ///
        (rcap ci_lo ci_hi xpos if outcome == "employed_y", lcolor(stc1)) ///
        (scatter coef xpos if outcome == "employed_y", mcolor(stc1) msymbol(O) msize(small)) ///
        (rcap ci_lo ci_hi xpos if outcome == "full_time_y", lcolor(stc2)) ///
        (scatter coef xpos if outcome == "full_time_y", mcolor(stc2) msymbol(D) msize(small)) ///
        (rcap ci_lo ci_hi xpos if outcome == "part_time_y", lcolor(stc3)) ///
        (scatter coef xpos if outcome == "part_time_y", mcolor(stc3) msymbol(T) msize(small)) ///
        , ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        ytitle("Average Treatment Effect (pp)") ///
        xtitle("Weeks worked per year (bins)") ///
        xlabel(1 "1-13" 2 "14-26" 3 "27-39" 4 "40-47" 5 "48-49" 6 "50-52", nogrid labsize(small)) ///
        ylabel(-4(2)4, angle(0) labsize(small)) ///
        legend(order(2 "Any Employment" 4 "Full-Time" 6 "Part-Time") ///
               rows(1) position(6) size(small))

    ** Save combined figure
    graph export "${results}figures/fig_weeks.jpg", as(jpg) name("Graph") quality(100) replace

    ** Also save as PNG
    graph export "${results}figures/fig_weeks.png", ///
        as(png) name("Graph") width(2400) height(1600) replace

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        graph export "${ol_fig}fig_weeks.jpg", as(jpg) quality(100) replace
    }

    ** Export coefficients for reference
    export delimited "${results}tables/fig_weeks_coefficients.csv", replace

restore

** =============================================================================
** End
** =============================================================================

clear
log close log_03_fig_weeks
