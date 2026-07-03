** TAXSIM warm-up test: single mother, 2 kids, $15,000 wages, CA, TY2016.
** Expected: positive federal EITC (v25) and positive CA EITC (v39).
** Run from repo root: stata-mp -b do code/hpc/test_taxsim.do

clear all
set more off

global dir "`c(pwd)'/"

cd "${dir}data/taxsim"

clear
set obs 1
gen taxsimid = 1
gen year = 2016
gen state = 5        // SOI code for California
gen mstat = 1
gen page = 30
gen depx = 2
gen dep17 = 2
gen dep18 = 2
gen pwages = 15000

taxsimlocal35, full

cd "${dir}"

import delimited "${dir}data/taxsim/results.raw", clear
di "=== TAXSIM TEST RESULTS ==="
list taxsimid year fiitax siitax v25 v39, clean noobs
qui summ v25
if r(mean) > 0 & r(mean) < . di "TAXSIM TEST PASSED: fed EITC = " r(mean)
else di "TAXSIM TEST FAILED: fed EITC = " r(mean)
