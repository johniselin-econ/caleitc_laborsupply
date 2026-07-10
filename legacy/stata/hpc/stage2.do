/*******************************************************************************
Phase 0 — Stage 2: Appendix E alternative inference (parallelized, fixed code)
Run from repo root: stata-mp -b do code/hpc/stage2.do
Requires data/final/acs_working_file.dta from Stage 1.
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

log using "${logs}phase0_stage2_${date}", replace text

set seed 56403
global seed 56403

global start_year = 2012
global end_year = 2017
global debug = 0

** Workers = tasks (12 = 3 outcomes x 4 specs)
global ncores = 12

do ${code}utils/globals.do
do ${code}utils/programs.do

** Load the (fixed) parallel bootstrap programs, then run the battery
do ${code}04_appE_inference_programs.do
do ${code}04_appE_inference_parallel.do

di _n "===== STAGE 2 COMPLETE ====="

capture log close _all
