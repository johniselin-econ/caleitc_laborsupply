/*******************************************************************************
Phase 0 — Stage 3: validation of the recovered education scripts
Run from repo root: stata-mp -b do code/hpc/stage3_educ.do

Runs 03_tab_main_educ.do and 03_fig_event_emp_educ.do (both re-transcribed
verbatim from the 2026-03-05 run logs) against the rebuilt working file.
Validate afterwards with git diff: outputs should match the committed
tab_main_educ_{1,2,3,end}.tex and fig_event_emp_educ_coefficients.csv
to the digit (targets in the script headers).
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

** No Overleaf export on this machine
global oth_path ""
global ol_fig   ""
global ol_tab   ""
global overleaf = 0

log using "${logs}phase0_stage3_educ_${date}", replace text

set seed 56403
global seed 56403

capture set scheme plotplainblind
capture graph set window fontface "Times New Roman"

global start_year = 2012
global end_year = 2017

global debug = 0

** Load global macros and utility programs
do ${code}utils/globals.do
do ${code}utils/programs.do

** Tables first (graphics failure in batch mode must not block table export)
capture noisily do ${code}03_tab_main_educ.do

capture noisily do ${code}03_fig_event_emp_educ.do

di _n "===== STAGE 3 EDUC COMPLETE ====="

capture log close _all
