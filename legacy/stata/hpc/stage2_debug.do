/*******************************************************************************
Phase 0 — Stage 2 DEBUG: Appendix E inference, small-B validation run
Same as stage2.do but with debug = 1 (B = 10, B_ri = 4) to exercise every
code path cheaply before the full battery. Outputs carry a _debug suffix.
Run from repo root: stata-mp -b do code/hpc/stage2_debug.do
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

log using "${logs}phase0_stage2_debug_${date}", replace text

set seed 56403
global seed 56403

global start_year = 2012
global end_year = 2017
global debug = 1

** Workers = tasks (12 = 3 outcomes x 4 specs)
global ncores = 12

do ${code}utils/globals.do
do ${code}utils/programs.do

** Load the parallel bootstrap programs, then run the battery
do ${code}04_appE_inference_programs.do
do ${code}04_appE_inference_parallel.do

di _n "===== STAGE 2 DEBUG COMPLETE ====="

capture log close _all
