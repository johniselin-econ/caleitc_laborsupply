/*******************************************************************************
File Name:      code/diagnostics/01_quad_het_adults.do
Creator:        John Iselin (with Claude Code)
Date:           2026-09-01

Purpose:        Does the household-composition heterogeneity (sec:het_adults)
                survive the fourth difference?

                The committed triple-difference heterogeneity table
                (results/tables/tab_het_adults_2.tex) puts essentially ALL of
                the full-time decline in 3+ adult households (-7.3 pp ***),
                with 1- and 2-adult households small and insignificant.

                The quadruple difference (03_tab_quad_diff.do) adds college
                women as a fourth dimension, netting out any CA x post x QC
                confounder common to both education groups. Pooled, it kills
                the FT effect (-0.08 / -0.18, n.s.) while PT survives (+1.9 **).

                QUESTION: within the 3+ adult cell, does the FT effect survive
                the fourth difference? If it does not, the composition
                heterogeneity is a confounder signature, not a credit response.

                Blocks:
                  (A) GOLDEN: pooled quad-diff  -> tab_quad_diff_*.tex
                  (B) GOLDEN: triple-diff het   -> tab_het_adults_*.tex
                  (C) NEW:    quad-diff by adult count (subsamples)
                  (D) NEW:    pooled quad-diff x adult-count interaction

Project: CalEITC Labor Supply Effects
*******************************************************************************/

clear all
set more off
set linesize 200

** ---- Paths -----------------------------------------------------------------
** Paths are derived from the working directory -- run from the repo root
** (mirrors 00_caleitc.do). No machine-specific paths.
global dir     "`c(pwd)'/"
global dir : subinstr global dir "\" "/" , all
global data    "${dir}data/"
global out     "${dir}results/diagnostics/"
global tmp     "${dir}data/tmp/"

capture mkdir "data/tmp"
capture mkdir "results/diagnostics"

** ---- Globals (mirror utils/globals.do + 00_caleitc.do) ---------------------
global outcomes   "employed_y full_time_y part_time_y"
global controls   "education age_bracket minage_qc race_group hispanic hh_adult_ct"
global unemp      "state_unemp"
global minwage    "mean_st_mw"
global clustervar "state_fips"
global did_base   "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"
global start_year = 2012
global end_year   = 2017

** Quad-diff demographic controls (education excluded -- absorbed by the
** noncollege interactions; 03_tab_quad_diff.do:34)
local qcontrols "age_bracket minage_qc race_group hispanic hh_adult_ct"

** Saturated 3-way FEs (03_tab_quad_diff.do:78)
local quad_fes "state_fips#year#qc_ct state_fips#year#noncollege state_fips#qc_ct#noncollege year#qc_ct#noncollege"

** =============================================================================
** Load the quad-diff sample (college + non-college), streamed from disk
** =============================================================================

use weight $outcomes incearn_real education age_bracket minage_qc race_group ///
    hispanic hh_adult_ct $unemp $minwage qc_* year ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        state_status > 0 & ///
        inrange(year, ${start_year}, ${end_year}) ///
    using "${data}final/acs_working_file.dta", clear

di _n "Loaded quad-diff sample (college + non-college): N = " _N

** ---- DID variables (mirror setup_did_vars) ---------------------------------
gen ca   = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)
replace hh_adult_ct = 3 if hh_adult_ct > 3

gen noncollege   = (education < 4)
gen quad_treated = (noncollege == 1 & ca == 1 & post == 1 & qc_present == 1)

** Scale outcomes to percentage points
foreach out of global outcomes {
    replace `out' = `out' * 100
}
replace incearn_real = 0 if incearn_real == .

tab hh_adult_ct noncollege, missing

** ---- Results collector -----------------------------------------------------
capture postclose res
postfile res str12 design str8 adults str14 outcome byte spec ///
    double b se pval nobs r2a ntreat using "${tmp}quad_het_adults.dta", replace

** =============================================================================
** (A) GOLDEN -- pooled quadruple difference (should match tab_quad_diff)
**     targets: emp 1.824254 / 1.592066 ; FT -0.0799746 / -0.1762789 ;
**              PT 1.904228 / 1.768345 ; N = 761,195
** =============================================================================

di _n "===== (A) GOLDEN: pooled quad-diff ====="

foreach out of global outcomes {

    forvalues s = 1/2 {

        if `s' == 1 local abs "`quad_fes'"
        else        local abs "`quad_fes' `qcontrols'"

        qui reghdfe `out' quad_treated [aw=weight], ///
            absorb(`abs') vce(cluster $clustervar)

        qui count if quad_treated == 1
        local nt = r(N)

        local b  = _b[quad_treated]
        local se = _se[quad_treated]
        local p  = 2*ttail(e(df_r), abs(`b'/`se'))

        di %-14s "`out'" "  spec `s'   b = " %9.4f `b' "   se = " %8.4f `se' ///
           "   p = " %6.4f `p' "   N = " %12.0fc e(N)

        post res ("quad") ("all") ("`out'") (`s') (`b') (`se') (`p') ///
            (e(N)) (e(r2_a)) (`nt')
    }
}

** =============================================================================
** (B) GOLDEN -- triple-difference heterogeneity by adult count
**     non-college only, spec 4 (full demographic + economic controls)
**     targets (tab_het_adults_2.tex, full_time_y):
**       All -4.1(0.8)*** | 1 adult -1.6(1.6) | 2 adults -1.9(1.4) | 3+ -7.3(1.3)***
**       N: 461,616 / 133,712 / 164,039 / 163,865
** =============================================================================

di _n "===== (B) GOLDEN: triple-diff het by adult count (non-college) ====="

foreach out of global outcomes {

    forvalues i = 0/3 {

        if `i' == 0 {
            local cond "noncollege == 1"
            local alab "all"
        }
        else {
            local cond "noncollege == 1 & hh_adult_ct == `i'"
            local alab "`i'"
        }

        qui reghdfe `out' treated c.$unemp#i.qc_ct c.$minwage#i.qc_ct ///
            if `cond' [aw=weight], ///
            absorb($did_base $controls) vce(cluster $clustervar)

        qui count if treated == 1 & `cond'
        local nt = r(N)

        local b  = _b[treated]
        local se = _se[treated]
        local p  = 2*ttail(e(df_r), abs(`b'/`se'))

        di %-14s "`out'" "  adults `alab'   b = " %9.4f `b' "   se = " %8.4f `se' ///
           "   p = " %6.4f `p' "   N = " %12.0fc e(N)

        post res ("triple") ("`alab'") ("`out'") (4) (`b') (`se') (`p') ///
            (e(N)) (e(r2_a)) (`nt')
    }
}

** =============================================================================
** (C) NEW -- quadruple difference WITHIN each adult-count cell
**     Same 4-way treatment and saturated FEs, estimated on the subsample of
**     households with 1 / 2 / 3+ adults (college + non-college both present
**     within each cell, so the fourth difference is identified).
**     hh_adult_ct is constant within cell -> dropped from the control list.
** =============================================================================

di _n "===== (C) NEW: quad-diff by adult count ====="

local qcontrols_sub "age_bracket minage_qc race_group hispanic"

forvalues i = 1/3 {

    di _n "----- hh_adult_ct == `i' -----"

    foreach out of global outcomes {

        forvalues s = 1/2 {

            if `s' == 1 local abs "`quad_fes'"
            else        local abs "`quad_fes' `qcontrols_sub'"

            qui reghdfe `out' quad_treated if hh_adult_ct == `i' [aw=weight], ///
                absorb(`abs') vce(cluster $clustervar)

            qui count if quad_treated == 1 & hh_adult_ct == `i'
            local nt = r(N)

            local b  = _b[quad_treated]
            local se = _se[quad_treated]
            local p  = 2*ttail(e(df_r), abs(`b'/`se'))

            di %-14s "`out'" "  adults `i'  spec `s'   b = " %9.4f `b' ///
               "   se = " %8.4f `se' "   p = " %6.4f `p' "   N = " %12.0fc e(N)

            post res ("quad") ("`i'") ("`out'") (`s') (`b') (`se') (`p') ///
                (e(N)) (e(r2_a)) (`nt')
        }
    }
}

postclose res

** =============================================================================
** (D) NEW -- pooled interaction version (efficiency check on block C)
**     Keeps the full sample and the common FE structure, interacting the
**     4-way treatment with adult count. Guards against the subsample results
**     being an artifact of splitting the FEs.
** =============================================================================

di _n "===== (D) NEW: pooled quad-diff x adult-count interaction ====="

foreach out of global outcomes {

    di _n "----- `out' -----"

    reghdfe `out' i.hh_adult_ct##c.quad_treated [aw=weight], ///
        absorb(`quad_fes' age_bracket minage_qc race_group hispanic) ///
        vce(cluster $clustervar)

    ** Marginal 4-way effect within each adult-count cell
    forvalues i = 1/3 {
        qui lincom quad_treated + `i'.hh_adult_ct#c.quad_treated
        di "  adults `i':  b = " %9.4f r(estimate) "   se = " %8.4f r(se) ///
           "   p = " %6.4f r(p)
    }
}

** =============================================================================
** Export tidy results
** =============================================================================

use "${tmp}quad_het_adults.dta", clear
gen stars = cond(pval < .01, "***", cond(pval < .05, "**", cond(pval < .1, "*", "")))
order design adults outcome spec b se pval stars nobs r2a ntreat
list, sepby(design outcome) noobs
export delimited using "${out}quad_het_adults.csv", replace

di _n "QUAD-HET-ADULTS COMPLETE"
