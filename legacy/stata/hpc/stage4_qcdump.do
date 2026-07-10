/*******************************************************************************
Phase 2 — Stage 4: golden-file dump for the qc_assignment R port
Run from repo root: stata-mp -b do code/hpc/stage4_qcdump.do

For validation years {2012, 2015}: replicates Steps 1-2 of 01_clean_data.do
verbatim (pre-QC prep + qc_assignment), then exports the post-assignment
state keyed by (serial, pernum) to data/interim/qc_golden_<year>.csv.
The R port (code/R/utils/qc_assignment.R) must reproduce qc_ct, matched,
and min_qc_age row-for-row (see code/R/validate/validate_qc_assignment.R).
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

log using "${logs}phase2_stage4_qcdump_${date}", replace text

set seed 56403
global seed 56403

do ${code}utils/globals.do
do ${code}utils/programs.do

foreach y in 2012 2015 {

    di _n "===== Golden dump for year `y' ====="

    ** Import CSV (mirrors 01_clean_data.do Step 1 verbatim)
    import delimited "${data}acs/acs_`y'.csv", clear

    gegen long hh_id = group(year serial)

    foreach var in sample cbserial {
        capture drop `var'
    }

    gen byte child = (age <= 17)
    gen byte adult = (age >= 18)
    gen byte elder = (age >= 65)

    gen unit_id = pernum
    replace unit_id = sploc if marst == 1 & sploc != 0 & pernum > sploc

    bysort hh_id unit_id: gen byte unit_ct = _N

    gen byte age_test = (age < 19) | ((age < 24) & (school == 2))
    gen byte citizen_test = (citizen != 3)
    gen byte joint_test = !inlist(marst, 1, 2, 3)

    gen byte qc = (age_test == 1) & (citizen_test == 1) & (joint_test == 1)

    gen byte hoh = (related == 101)
    gen byte sibling = (related == 701)
    gen byte foster = (related == 1242)
    gen byte grandchild = (related == 901)

    ** Step 2 (verbatim)
    drop if missing(pernum)

    qc_assignment

    ** Export golden state (age is post-mutation: 0 recoded to 1)
    keep serial pernum age qc hoh sibling foster grandchild ///
        momloc momloc2 poploc poploc2 qc_ct matched min_qc_age
    export delimited using "${data}interim/qc_golden_`y'.csv", replace

    di "Exported data/interim/qc_golden_`y'.csv (N = " _N ")"
}

di _n "===== STAGE 4 QC DUMP COMPLETE ====="

capture log close _all
