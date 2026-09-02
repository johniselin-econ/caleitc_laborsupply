/*******************************************************************************
File Name:      quad_het_adults_placebo.do
Creator:        John Iselin (with Claude Code)
Date:           2026-09-01

Purpose:        Follow-up diagnostics on the household-composition heterogeneity.

                (E) COLLEGE PLACEBO BY ADULT COUNT. The pooled college placebo
                    shows a full-time decline of -2.0 to -2.3 pp for a group
                    that is largely CalEITC-ineligible. If that placebo decline
                    is ALSO concentrated in 3+ adult households, the household
                    gradient is a confounder signature rather than a credit
                    response -- and it is exactly what the fourth difference
                    nets out.

                (F) COMPOSITION. hh_adult_ct is measured post-treatment. If the
                    3+ adult cell is itself growing differentially in CA after
                    2014 (doubling up), conditioning on it is conditioning on a
                    collider and the cell-specific estimates mix a real
                    behavioral response with selection into the cell.

Project: CalEITC Labor Supply Effects
*******************************************************************************/

clear all
set more off
set linesize 200

** Paths are derived from the working directory -- run from the repo root
** (mirrors 00_caleitc.do). No machine-specific paths.
global dir     "`c(pwd)'/"
global dir : subinstr global dir "\" "/" , all
global data    "${dir}data/"
global out     "${dir}results/diagnostics/"
global tmp     "${dir}data/tmp/"

capture mkdir "data/tmp"
capture mkdir "results/diagnostics"


global outcomes   "employed_y full_time_y part_time_y"
global unemp      "state_unemp"
global minwage    "mean_st_mw"
global clustervar "state_fips"
global did_base   "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"
global start_year = 2012
global end_year   = 2017

** Controls for an education-homogeneous sample (04_appA_tab_col_placebo.do:28)
local controls "age_bracket minage_qc race_group hispanic hh_adult_ct"

** =============================================================================
** Load full sample (college + non-college)
** =============================================================================

local loadvars "weight $outcomes age_bracket minage_qc race_group hispanic hh_adult_ct"
local loadvars "`loadvars' $unemp $minwage qc_* year"
local loadvars "`loadvars' female married in_school age_sample_20_49 citizen_test"
local loadvars "`loadvars' state_fips state_status education"

use `loadvars' ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        state_status > 0 & ///
        inrange(year, ${start_year}, ${end_year}) ///
    using "${data}final/acs_working_file.dta", clear

gen ca   = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)
replace hh_adult_ct = 3 if hh_adult_ct > 3
gen noncollege = (education < 4)

foreach out of global outcomes {
    replace `out' = `out' * 100
}

capture postclose res2
postfile res2 str12 design str8 adults str14 outcome ///
    double b se pval nobs r2a ntreat using "${tmp}quad_het_adults_placebo.dta", replace

** =============================================================================
** (E) College placebo, by adult count  (spec 4: full controls)
**     Pooled targets (tab_col_placebo_*.tex, spec 4, N = 299,579):
**       employed -1.5 (0.5)*** | full-time -2.0 (1.1)* | part-time 0.5 (0.8)
** =============================================================================

di _n "===== (E) College placebo (education == 4) by adult count ====="

foreach out of global outcomes {

    di _n "----- `out' -----"

    forvalues i = 0/3 {

        if `i' == 0 {
            local cond "noncollege == 0"
            local alab "all"
        }
        else {
            local cond "noncollege == 0 & hh_adult_ct == `i'"
            local alab "`i'"
        }

        qui reghdfe `out' treated c.$unemp#i.qc_ct c.$minwage#i.qc_ct ///
            if `cond' [aw=weight], ///
            absorb($did_base `controls') vce(cluster $clustervar)

        qui count if treated == 1 & `cond'
        local nt = r(N)

        local b  = _b[treated]
        local se = _se[treated]
        local p  = 2*ttail(e(df_r), abs(`b'/`se'))

        di "  adults `alab':  b = " %9.4f `b' "   se = " %8.4f `se' ///
           "   p = " %6.4f `p' "   N = " %12.0fc e(N)

        post res2 ("col_placebo") ("`alab'") ("`out'") (`b') (`se') (`p') ///
            (e(N)) (e(r2_a)) (`nt')
    }
}

postclose res2

** =============================================================================
** (F) COMPOSITION -- is the 3+ adult cell itself moving?
**     Triple-difference on the indicator for living in a 3+ adult household.
**     A nonzero coefficient means the conditioning variable is post-treatment.
** =============================================================================

di _n "===== (F) Composition: is membership in the 3+ adult cell endogenous? ====="

gen byte adult3p = (hh_adult_ct == 3) * 100
gen byte adult1  = (hh_adult_ct == 1) * 100
gen byte adult2  = (hh_adult_ct == 2) * 100

foreach v in adult1 adult2 adult3p {

    di _n "----- `v' : non-college -----"
    reghdfe `v' treated c.$unemp#i.qc_ct c.$minwage#i.qc_ct ///
        if noncollege == 1 [aw=weight], ///
        absorb($did_base age_bracket minage_qc race_group hispanic) ///
        vce(cluster $clustervar)

    di _n "----- `v' : college -----"
    reghdfe `v' treated c.$unemp#i.qc_ct c.$minwage#i.qc_ct ///
        if noncollege == 0 [aw=weight], ///
        absorb($did_base age_bracket minage_qc race_group hispanic) ///
        vce(cluster $clustervar)
}

** Raw trend: share in 3+ adult HH, by CA x QC x year (non-college)
di _n "===== Raw share in 3+ adult households, non-college, by CA x QC x year ====="
table year ca qc_present if noncollege == 1 [aw=weight], ///
    statistic(mean adult3p) nformat(%6.2f)

** =============================================================================
** Export
** =============================================================================

use "${tmp}quad_het_adults_placebo.dta", clear
gen stars = cond(pval < .01, "***", cond(pval < .05, "**", cond(pval < .1, "*", "")))
order design adults outcome b se pval stars nobs r2a ntreat
list, sepby(outcome) noobs
export delimited using "${out}quad_het_adults_placebo.csv", replace

di _n "QUAD-HET-ADULTS-PLACEBO COMPLETE"
