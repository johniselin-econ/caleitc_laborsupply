/*******************************************************************************
Phase 0 — Stage 1: data cleaning + priority results
Run from repo root: stata-mp -b do code/hpc/stage1.do

Mirrors the preliminaries of 00_caleitc.do but:
  - skips the R data-download steps (data already in data/acs, data/interim)
  - sets overleaf = 0 (no Dropbox/Overleaf path on this cluster)

Runs: 01_clean_data (incl. TAXSIM), then 03_tab_main (validation against
committed outputs), 03_tab_quad_diff, 03_tab_oster_bounds, 03_tab_main_educ
(reconstruction validation), 04_appA_tab_col_placebo.
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

log using "${logs}phase0_stage1_${date}", replace text

set seed 56403
global seed 56403

capture set scheme plotplainblind
capture graph set window fontface "Times New Roman"

** Years (analysis / data)
global start_year = 2012
global end_year = 2017
global start_year_data = 2006
global end_year_data = 2019

global debug = 0

** Load global macros and utility programs
do ${code}utils/globals.do
do ${code}utils/programs.do

** =============================================================================
** (01) Data cleaning + TAXSIM simulations
** =============================================================================

do ${code}01_clean_data.do

** =============================================================================
** Priority results (each wrapped so a graphics failure in batch mode
** does not halt subsequent table production)
** =============================================================================

** Validation: reproduce committed main table
capture noisily do ${code}03_tab_main.do

** Quadruple-difference (education as 4th dimension)
capture noisily do ${code}03_tab_quad_diff.do

** Oster (2019) bounds
capture noisily do ${code}03_tab_oster_bounds.do

** Education-stratified reconstruction (validate vs committed outputs)
capture noisily do ${code}03_tab_main_educ.do

** College placebo table (for the bounding discussion)
capture noisily do ${code}04_appA_tab_col_placebo.do

di _n "===== STAGE 1 COMPLETE ====="

log close _all
