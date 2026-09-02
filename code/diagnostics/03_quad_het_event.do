/*******************************************************************************
File Name:      code/diagnostics/03_quad_het_event.do
Creator:        John Iselin (with Claude Code)
Date:           2026-09-01

Purpose:        Event studies for full-time and part-time work, by household
                adult count, under three designs:

                  triple   -- triple difference, non-college (the paper's
                              baseline sample); CA x post x QC
                  placebo  -- same specification on COLLEGE women (education
                              == 4), who are largely CalEITC-ineligible
                  quad     -- quadruple difference, subsample version: the
                              4-way CA x post x QC x noncollege contrast
                              estimated within each adult-count cell

                Event variable follows setup_did_vars: it equals the survey
                year for the treated cell and the base year (2014) for every
                other observation, so b2014 gives year-by-year treatment
                coefficients relative to 2014.

Output:         data/tmp/quad_het_event.csv
                  design adults outcome year b se lo hi

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
global did_event  "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"
global start_year = 2012
global end_year   = 2017

** Education-homogeneous demographic controls (education excluded)
local hcontrols "age_bracket minage_qc race_group hispanic hh_adult_ct"
local hcontrols_sub "age_bracket minage_qc race_group hispanic"

** Saturated 3-way FEs for the quadruple difference
local quad_fes "state_fips#year#qc_ct state_fips#year#noncollege state_fips#qc_ct#noncollege year#qc_ct#noncollege"

** =============================================================================
** Load
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

di _n "Loaded: N = " _N

gen ca   = (state_fips == 6)
gen post = (year > 2014)
replace hh_adult_ct = 3 if hh_adult_ct > 3
gen noncollege = (education < 4)

** Event variables
gen trip_event = cond(qc_present == 1 & ca == 1, year, 2014)
gen quad_event = cond(noncollege == 1 & ca == 1 & qc_present == 1, year, 2014)

foreach out of global outcomes {
    replace `out' = `out' * 100
}

capture postclose ev
postfile ev str10 design str6 adults str14 outcome int yr ///
    double b se lo hi using "${tmp}quad_het_event.dta", replace

** Helper: harvest coefficients from the active estimation
** (called after each reghdfe; `evar' is the event variable name)

** =============================================================================
** Loop: designs x adult cells x outcomes
** =============================================================================

foreach design in triple placebo quad {

    ** Sample restriction and event variable per design
    if "`design'" == "triple" {
        local edcond "noncollege == 1"
        local evar   "trip_event"
    }
    if "`design'" == "placebo" {
        local edcond "noncollege == 0"
        local evar   "trip_event"
    }
    if "`design'" == "quad" {
        local edcond "1 == 1"
        local evar   "quad_event"
    }

    forvalues i = 0/3 {

        if `i' == 0 {
            local cond "`edcond'"
            local alab "all"
            local ctrl "`hcontrols'"
        }
        else {
            local cond "`edcond' & hh_adult_ct == `i'"
            local alab "`i'"
            local ctrl "`hcontrols_sub'"
        }

        foreach out in full_time_y part_time_y {

            di _n "===== `design' | adults `alab' | `out' ====="

            if "`design'" == "quad" {
                capture noisily reghdfe `out' b2014.`evar' if `cond' [aw=weight], ///
                    absorb(`quad_fes' `ctrl') vce(cluster $clustervar)
            }
            else {
                capture noisily reghdfe `out' b2014.`evar' ///
                    c.$unemp#i.qc_ct c.$minwage#i.qc_ct if `cond' [aw=weight], ///
                    absorb($did_event `ctrl') vce(cluster $clustervar)
            }

            if _rc != 0 {
                di as error "  FAILED (rc = " _rc ") -- skipping"
                continue
            }

            forvalues y = 2012/2017 {

                local bb = .
                local ss = .

                if `y' == 2014 {
                    local bb = 0
                    local ss = 0
                }
                else {
                    capture local bb = _b[`y'.`evar']
                    capture local ss = _se[`y'.`evar']
                }

                if `bb' != . {
                    local lo = `bb' - 1.96 * `ss'
                    local hi = `bb' + 1.96 * `ss'
                    post ev ("`design'") ("`alab'") ("`out'") (`y') ///
                        (`bb') (`ss') (`lo') (`hi')
                    di "   " `y' ":  b = " %8.3f `bb' "  se = " %7.3f `ss'
                }
            }
        }
    }
}

postclose ev

** =============================================================================
** Export
** =============================================================================

use "${tmp}quad_het_event.dta", clear
order design adults outcome yr b se lo hi
sort design outcome adults yr
list, sepby(design outcome adults) noobs
export delimited using "${out}quad_het_event.csv", replace

di _n "QUAD-HET-EVENT COMPLETE"
