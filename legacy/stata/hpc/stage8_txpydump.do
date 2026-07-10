/*******************************************************************************
Phase 2 — Stage 8b: byte-exact TAXSIM sim-2 input dump (txpydata replica)

Run from repo root: stata-mp -b do code/hpc/stage8_txpydump.do

Motivation: the sim-2 cell validation with the golden (contaminated) sage
substituted STILL fails on 303 fed / 117 state cells (job 17098348), so a
second divergence beyond the sage bug exists. Suspect: taxsimlocal35.ado
writes the TAXSIM input file with `outsheet`, which uses variables' DISPLAY
FORMATS — the money vars are `gen double` (default %10.0g, ~9 significant
digits). For 2014 the values are clean ACS integers (sim 1/3 validated
exactly), but sim-2 reflates by cpi_y/cpi_2014, producing long decimal tails
that outsheet truncates while the R port sends full precision. Near TAXSIM's
internal discretization (the $50 EITC table brackets) a ~1e-4 input diff can
flip a row's EITC by dollars.

This dump replicates 01_clean_data.do section (4) (append), the section (5)
input regeneration (lines 903-981) and the sim-2 stacking/reflation
(lines 995-1057) VERBATIM, then

  (a) exports the stacked cell metadata keyed by the final taxsimid
      (data/interim/sim2_stack_meta.csv, full precision), and
  (b) replicates taxsimlocal35.ado's outsheet call byte-for-byte
      (data/interim/sim2_txpydata_golden.raw) — same variables, same
      txpyvars column order, same display formats, mtr = 85, idtl = 2
      (+10 on the last row).

Feeding (b) through taxsim35.exe reproduces the original run's results.raw
exactly, isolating the input-formatting artifact from everything downstream.
*******************************************************************************/

capture log close _all
clear matrix
clear all
set more off

global pr_name "caleitc"
global date "`: di %tdCY-N-D daily("$S_DATE", "DMY")'"

global dir      "`c(pwd)'/"
global dir : subinstr global dir "\" "/" , all
global code     "${dir}code/"
global data     "${dir}data/"
global results  "${dir}results/"
global logs     "${code}logs/"

cd ${dir}

global oth_path ""
global ol_fig   ""
global ol_tab   ""
global overleaf = 0

log using "${logs}phase2_stage8_txpydump_${date}", replace text

set seed 56403
global seed 56403

do ${code}utils/globals.do
do ${code}utils/programs.do

global start_year_data = 2006
global end_year_data = 2019

** ---------------------------------------------------------------------------
** Evidence for the log: outsheet writes doubles with their display format
** (%10.0g default), truncating long decimal tails
** ---------------------------------------------------------------------------

clear
set obs 2
gen double x = 32456.789456789 in 1
replace  x  = 5123.4567890123 in 2
gen double y = x
format y %21.0g
outsheet x y using "${data}interim/outsheet_fmt_test.csv", replace comma nolabel
di _n "outsheet format test (x = default %10.0g, y = %21.0g):"
type "${data}interim/outsheet_fmt_test.csv"
clear

** ---------------------------------------------------------------------------
** Section (4) verbatim: append all years
** ---------------------------------------------------------------------------

forvalues y = $start_year_data(1)$end_year_data {
    capture confirm file "${data}final/acs_`y'_clean.dta"
    if _rc == 0 {
        append using "${data}final/acs_`y'_clean.dta"
    }
}

di "Combined file: " _N " rows"

** ---------------------------------------------------------------------------
** Section (5) input regeneration verbatim (01_clean_data.do:903-981)
** ---------------------------------------------------------------------------

sort hh_id unit_id pernum
gegen double taxsimid = group(hh_id unit_id)

capture confirm variable state_soi
if _rc != 0 {
    recode state_fips ///
        (1=1) (2=2) (4=3) (5=4) (6=5) (8=6) (9=7) (10=8) (11=9) ///
        (12=10) (13=11) (15=12) (16=13) (17=14) (18=15) (19=16) (20=17) (21=18) ///
        (22=19) (23=20) (24=21) (25=22) (26=23) (27=24) (28=25) (29=26) (30=27) ///
        (31=28) (32=29) (33=30) (34=31) (35=32) (36=33) (37=34) (38=35) (39=36) ///
        (40=37) (41=38) (42=39) (44=40) (45=41) (46=42) (47=43) (48=44) (49=45) ///
        (50=46) (51=47) (53=48) (54=49) (55=50) (56=51), gen(state_soi)
}

gen state = state_soi

capture confirm variable mstat
if _rc != 0 {
    gen byte mstat = 1
    replace mstat = 2 if married == 1
    replace mstat = 6 if mfs == 1
}

gen byte depx = qc_ct

gen page = age

gen sage = 0
bysort hh_id unit_id (pernum): gen tmp_max_age = age[_N]
bysort hh_id unit_id (pernum): gen tmp_min_age = age[1]
replace sage = tmp_max_age if age == tmp_min_age & married == 1 & unit_ct > 1
replace sage = tmp_min_age if age == tmp_max_age & married == 1 & unit_ct > 1
drop tmp_max_age tmp_min_age

gen double pwages = max(incwage_nom, 0)

gen double swages = max(incwage_tax_nom - incwage_nom, 0)

gen double psemp = incse_nom

gen double ssemp = incse_tax_nom - incse_nom

gen double intrec = max(incinvst_tax_nom, 0)

gen double otherprop = inctot_tax_nom
replace otherprop = otherprop - max(incwage_tax_nom, 0)
replace otherprop = otherprop - incse_tax_nom
replace otherprop = otherprop - incinvst_tax_nom
replace otherprop = otherprop - incwel_nom
replace otherprop = max(otherprop, 0)

gen byte primary_filer = (unit_id == pernum)

** ---------------------------------------------------------------------------
** Sim-2 stacking verbatim (01_clean_data.do:995-1057)
** ---------------------------------------------------------------------------

** Store CPI values
forvalues y = 2010(1)2019 {
    qui summ cpi99 if year == `y', meanonly
    local cpi_`y' = r(mean)
    di "cpi_`y' local = " %21.0g `cpi_`y''
}

** Create simulated CalEITC instrument using 2014 data
keep if year == 2014

** Keep primary filers only
keep if primary_filer == 1

** Keep required TAXSIM variables
keep taxsimid state mstat depx page sage pwages swages psemp ssemp intrec otherprop ///
    cpi99 education age_bracket female weight

** Order variables
order taxsimid state mstat depx page sage pwages swages psemp ssemp intrec otherprop ///
    cpi99 education age_bracket female weight

** Gen value to help with appending
gen append = 0

** Gen empty year variable
gen year = .

** Save as temporary file
tempfile sim_caleitc_append
save `sim_caleitc_append'
clear

** Loop over years
forvalues y = 2010/2019 {

    ** Append values
    append using `sim_caleitc_append'

    ** Adjust values for inflation
    foreach var of varlist pwages swages psemp ssemp intrec otherprop {
        replace `var' = `var' * (`cpi_`y'' / cpi99) if append == 0
    }

    ** Update year
    replace year = `y' if append == 0

    ** Adjust append helper
    replace append = 1
}

** Generate new taxsim id
rename taxsimid taxsimid_old
gsort year taxsimid_old
gen double taxsimid = _n
drop taxsimid_old

di "Stacked file: " _N " rows"

** ---------------------------------------------------------------------------
** (a) Cell metadata for the collapse, keyed by the final taxsimid
** ---------------------------------------------------------------------------

preserve
keep taxsimid year state mstat depx education age_bracket female weight
format taxsimid weight %21.0g
export delimited using "${data}interim/sim2_stack_meta.csv", replace nolabel
restore

** ---------------------------------------------------------------------------
** (b) Byte-exact replica of taxsimlocal35.ado's outsheet
**     (keep/order from 01_clean_data.do:1058-1059, then the ado's gen
**     mtr/idtl and txpyvars column order; formats untouched = as generated)
** ---------------------------------------------------------------------------

** Keep TAXSIM input variables
keep taxsimid year state mstat depx page sage pwages swages psemp ssemp intrec otherprop
order taxsimid year state mstat depx page sage pwages swages psemp ssemp intrec otherprop

gen mtr = 85
gen idtl = 2
replace idtl = idtl + 10 if _n == _N

outsheet taxsimid year state mstat page sage depx pwages swages intrec otherprop ///
    idtl mtr psemp ssemp ///
    using "${data}interim/sim2_txpydata_golden.raw", replace comma nolabel

di "Exported data/interim/sim2_txpydata_golden.raw (N = " _N ")"

di _n "===== STAGE 8B TXPYDUMP COMPLETE ====="

capture log close _all
