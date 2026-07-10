/*******************************************************************************
Phase 2 — Stage 8: golden-input dump for the TAXSIM Simulation 2 R port
Run from repo root: stata-mp -b do code/hpc/stage8_sim2dump.do

Replicates 01_clean_data.do section (4) (append all per-year files) and the
section (5) TAXSIM input regeneration (lines 903-981) verbatim, then exports
the 2014 primary filers' sim-2 inputs keyed by (serial, pernum) to
data/interim/sim2_inputs_golden_2014.csv.

Motivation: the first sim-2 cell validation (job 17096067) failed on 0.5% of
cells, all qc_ct = 0 x married — the childless-EITC age-test cells. Suspected
cause: hh_id is a PER-YEAR dense rank (group(year serial) computed inside the
year loop), so on the combined file `bysort hh_id unit_id (pernum)` pools up
to 14 unrelated households and the regenerated sage (spouse age) picks up
other years' rows. This dump captures the sage (and all other inputs) the
original run actually fed TAXSIM, so the R port can isolate the divergence.
tmp_first_age/tmp_last_age are exported too (as tmp_first_dump/tmp_last_dump)
for diagnosis.
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

log using "${logs}phase2_stage8_sim2dump_${date}", replace text

set seed 56403
global seed 56403

do ${code}utils/globals.do
do ${code}utils/programs.do

** Year range globals are set in 00_caleitc.do, not utils/globals.do
global start_year_data = 2006
global end_year_data = 2019

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
gen tmp_first_dump = tmp_min_age
gen tmp_last_dump = tmp_max_age
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
** Export the sim-2 base (year == 2014, primary filers) keyed by serial/pernum
** ---------------------------------------------------------------------------

keep if year == 2014 & primary_filer == 1

keep serial pernum hh_id unit_id married unit_ct state mstat depx page sage ///
    tmp_first_dump tmp_last_dump pwages swages psemp ssemp intrec otherprop ///
    cpi99 education age_bracket female weight

format cpi99 %21.0g
format pwages swages psemp ssemp intrec otherprop %21.0g

export delimited using "${data}interim/sim2_inputs_golden_2014.csv", replace nolabel

di "Exported data/interim/sim2_inputs_golden_2014.csv (N = " _N ")"

di _n "===== STAGE 8 SIM2 DUMP COMPLETE ====="

capture log close _all
