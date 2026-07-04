/*******************************************************************************
File Name: 		00_caleitc.do
Creator: 		John Iselin
Date Update:	March 2026

Purpose: 	Runs the analysis on the labor supply effects of the CalEITC
			implementation in 2015

Authors: John Iselin

For more information, contact john.iselin@yale.edu


*******************************************************************************/

** =============================================================================
** RUN MODES:
**   AEJ:EP draft (main_aejep.tex):  Run as-is. Produces 12 main-text exhibits
**                                    + appendix material.
**   Full draft (main.tex):           Uncomment "DEMOTED" and "ARCHIVED" blocks
**                                    below to reproduce all 19+ exhibits.
** =============================================================================

** INSTALLATION
* net install github, from("https://haghish.github.io/github/")
* github install haghish/rcall, stable
* net install parallel, from(https://raw.github.com/gvegayon/parallel/stable/) replace
* ssc install ftools
* ssc install reghdfe
* ssc install ppmlhdfe
* ssc install fre
* ssc install coefplot
* ssc install estout
* ssc install gtools
* ssc install balancetable
* ssc install ivreghdfe
* ssc install _gwtmean
* ssc install rwolf2
* ssc install psacalc

** Preliminaries
capture log close
clear matrix
clear all
set more off

** Name of project
global pr_name "caleitc"

** Date of run
global date "`: di %tdCY-N-D daily("$S_DATE", "DMY")'"

** Set Directories
** NOTE: Update this path to match your local setup
** Example: global dir "C:/Users/yourname/Documents/GitHub/caleitc_laborsupply/"
global dir 		"`c(pwd)'/"
** Convert backslashes to forward slashes (prevents R escape errors on Windows)
global dir : subinstr global dir "\" "/" , all
global code 	"${dir}code/"				// CODE FILEPATH
global data 	"${dir}data/"				// DATA FILEPATH
global results 	"${dir}results/"			// RESULTS FILEPATH
global logs 	"${code}logs/"				// LOG FILE SUB-FILEPATH

** Set WD
cd ${dir}

** OVERLEAF FILE PATH
global oth_path  "C:/Users/ji252/Dropbox/Apps/Overleaf/CalEITC/"
global ol_fig    "${oth_path}figures/"
global ol_tab    "${oth_path}tables/"

** Start log file
log using "${logs}00_log_${pr_name}_${date}", replace text

** Set Seed
set seed 56403
global seed 56403

** Set scheme
set scheme plotplainblind

** Set Font
graph set window fontface "Times New Roman"

** Set parameters
local overwrite_csv = 0
local overwrite_bls = 0

** Years (ANALYSIS)
global start_year = 2012
global end_year = 2017

** Years (DATA)
global start_year_data = 2006
global end_year_data = 2019

** OVERLEAF OPTION (1=Save to overleaf, 0=save only locally)
global overleaf = 1

** DEBUG OPTION (1=debug on, 0=debug off)
global debug = 0

** Load global macros and utility programs
do ${code}utils/globals.do
do ${code}utils/programs.do

** =============================================================================
** (00) CALL R CODE TO IMPORT IPUMS DATA
** =============================================================================

** Note: R handles IPUMS API calls. Requires ipumsr package and API key.
** The R script downloads ACS data year-by-year to data/acs/ as RDS files.

rcall script "${code}R/api_code.R", ///
    args( project_root  <- "${dir}"; ///
          dir_data_acs  <- "${data}acs"; ///
          api_codes_path<- "${dir}api_codes.txt"; ///
          start_year    <- ${start_year_data}; ///
          end_year      <- ${end_year_data}; ///
          overwrite_csv <- as.logical(`overwrite_csv'); ///
    ) vanilla

** Download and prepare non-IPUMS data:
** - State and county FIPS codes
** - BLS unemployment data (state and county level)
** - State minimum wage data (Vaghul & Zipperer 2022)

rcall script "${code}R/01_data_prep_other.R", 	///
    args( dir_data_raw   <- "${data}raw"; 		///
          dir_data_int   <- "${data}interim"; 	///
          start_year_data<- ${start_year_data}; ///
          end_year_data  <- ${end_year_data}; 	///
          overwrite_bls  <- `overwrite_bls' 	///
    ) vanilla

** =============================================================================
** (01) DATA CLEANING
** =============================================================================

** Clean and prepare ACS data
** Data sources:
** 	(a) Individual-level ACS data via IPUMS USA
** 		- https://usa.ipums.org/usa/index.shtml
** 	(b) State-level unemployment via BLS API (downloaded in R)
** 	(c) County-level unemployment via BLS LAUS
** 	(d) State minimum wages via Vaghul & Zipperer (2022)

do ${code}01_clean_data.do

** =============================================================================
** (02) ANALYSIS
** =============================================================================

** Participation and mobility elasticity calculations
do ${code}02_elasticities.do

** Calculate Marginal Value of Public Funds for the CalEITC
** Estimates fiscal externalities from labor supply behavioral responses
do ${code}02_mvpf.do

** =============================================================================
** (03) MAIN TEXT — AEJ:EP REVISED DRAFT (9 figures, 3 tables = 12 exhibits)
** =============================================================================
** Organized by paper section to match main_aejep.tex

** -----------------------------------------------------------------------------
** Section 2: Policy Background
** -----------------------------------------------------------------------------

** Figure 1: EITC benefit schedules (TY 2016)
do ${code}03_fig_eitc_sched.do

** Figure 2: Histograms of California workers
do ${code}03_fig_earn_hist.do

** -----------------------------------------------------------------------------
** Section 3: Conceptual Framework
** -----------------------------------------------------------------------------

** Figure 3: Budget constraint for parent with 2 QC (2016)
do ${code}03_fig_budget.do

** -----------------------------------------------------------------------------
** Section 5.1: Main Results
** -----------------------------------------------------------------------------

** Table 1: Triple-difference estimates on annual employment
do ${code}03_tab_main.do

** Figure 4: Event-study estimates on annual employment
do ${code}03_fig_event_emp.do

** -----------------------------------------------------------------------------
** Section 5.2: Decomposition
** -----------------------------------------------------------------------------

** Figure 5: Effect by weekly hours worked
do ${code}03_fig_hours_bins.do

** -----------------------------------------------------------------------------
** Section 5.3: Robustness
** -----------------------------------------------------------------------------

** Table 2: County-panel weighted SDID estimates
do ${code}03_sdid_county.do

** Figure 6: College-educated sample event-study (falsification)
do ${code}03_fig_event_col_placebo.do

** (inline) Quadruple-difference: nets out CA x post x QC confounder
do ${code}03_tab_quad_diff.do

** (inline) Oster (2019) coefficient stability bounds
do ${code}03_tab_oster_bounds.do

** Education-stratified results: within-CA triple-diff by education
** (recovered from the 2026-03-05 run logs; see script headers)
do ${code}03_tab_main_educ.do
do ${code}03_fig_event_emp_educ.do

** -----------------------------------------------------------------------------
** Section 6: Earnings
** -----------------------------------------------------------------------------

** Table 3: Triple-difference estimates on annual earnings
do ${code}03_tab_earnings.do

** Figure 7: Changes in the earnings distribution over time
do ${code}03_fig_earn_bins.do

** -----------------------------------------------------------------------------
** Section 7: Heterogeneity
** -----------------------------------------------------------------------------

** Figure 8: Triple-difference employment effects, by number of adults
do ${code}03_tab_het_adults.do

** Own vs HH income event-study (TBD main/appendix placement)
do ${code}03_fig_event_earn.do

** -----------------------------------------------------------------------------
** Section 8: MVPF
** -----------------------------------------------------------------------------

** Figure 9: Distribution of MVPF estimates
do ${code}03_fig_mvpf_dist.do

** =============================================================================
** (04) APPENDIX MATERIAL
** =============================================================================

** -----------------------------------------------------------------------------
** DEMOTED from main text (were in main.tex, now appendix in main_aejep.tex)
** To reproduce full draft (main.tex), uncomment this block.
** -----------------------------------------------------------------------------
*do ${code}03_fig_emp_trends.do        // Employment trends (old Fig 4)
*do ${code}03_fig_weeks.do             // Weeks worked (old Fig 7)
*do ${code}03_fig_spec_curve.do        // Specification curves (old Fig 9)
*do ${code}03_tab_het_qc.do            // Het by QC count (old Fig 11)
*do ${code}03_tab_het_qc_age.do        // Het by QC age (old Fig 13)
*do ${code}03_fig_mvpf_spillovers.do   // Fiscal spillovers (old Fig 16)

** -----------------------------------------------------------------------------
** APPENDIX A: Additional Tables and Figures
** -----------------------------------------------------------------------------

** Appendix Table A.1: Sample states and population statistics
do ${code}04_appA_tab1.do

** Appendix Figure A.1: Federal & CA EITC benefits schedule, TY 2015 and 2017
do ${code}04_appA_fig_eitc_sched_15_17.do

** Appendix Figure A.2: EITC and CTC schedule by qualifying children (2016)
do ${code}04_appA_fig_eitc_ctc_sched.do

** Appendix Figure A.3: Post-2017 changes to federal and state tax credits
do ${code}04_appA_fig_tcja_yctc.do

** Appendix Figure A.4: State-level unemployment trends, 2005-2019
do ${code}04_appA_fig_unemp_trends.do

** Appendix Figure A.5: Binding state minimum wages in control pool, 2010-2017
do ${code}04_appA_fig_minwage.do

** Appendix Figure A.6: Triple-difference effect on the after-tax rate
do ${code}04_appA_fig_atr_event.do

** Appendix Tables A.2-A.3: Triple-difference balance test
do ${code}04_appA_tab_balance.do

** Appendix Table A.4: College-educated sample placebo test
do ${code}04_appA_tab_col_placebo.do

** Appendix Table: Earnings placebo — college-educated sample
do ${code}04_appA_tab_col_placebo_earn.do

** -----------------------------------------------------------------------------
** APPENDIX B: Labor Supply Effects Among Other Populations
** -----------------------------------------------------------------------------

** Appendix Figures B.1-B.3: Married women, Single men, Married men
do ${code}04_appB_otherpops.do

** -----------------------------------------------------------------------------
** APPENDIX C: Self-Employment
** -----------------------------------------------------------------------------

** Appendix Table C.1: Employment effects conditional on reporting wage income
do ${code}04_appC_tab_wage_emp.do

** Appendix Table C.2: Effects on self-employment
do ${code}04_appC_tab_self_emp.do

** Appendix Figure C.1: Event-study (employment restricted to wage workers)
do ${code}04_appC_fig_wage_emp.do

** Appendix Figure C.2: Event-study (annual self-employment)
do ${code}04_appC_fig_self_emp.do

** -----------------------------------------------------------------------------
** APPENDIX D: Inference
** -----------------------------------------------------------------------------

** Appendix Table D.1: Triple-difference estimates with different inference procedures
do ${code}04_appE_inference.do

** -----------------------------------------------------------------------------
** ARCHIVED / CUT (not in AEJ:EP submission)
** To reproduce full draft (main.tex), uncomment as needed.
** -----------------------------------------------------------------------------
*do ${code}03_tab_sim_inst.do          // Simulated instrument (archived — footnote only)
*do ${code}03_tab_hh_earn.do           // Household earnings — cut
*do ${code}03_tab_earn_hhcomp.do       // Earnings by HH composition — cut
*do ${code}03_tab_intensive.do         // Intensive margin — cut
*do ${code}03_fig_treat_by_earn.do     // Treatment effects by earnings bins — cut
*do ${code}03_tab_desc.do              // Deprecated — see 04_appA_tab1.do
*do ${code}03_sdid_state.do            // Superseded by county SDID
*do ${code}02_descriptives.do          // Summary statistics (standalone)
*do ${code}04_appA_tab_alt_threshold.do    // Alt threshold — cut from appendix
*do ${code}04_appA_fig_emp_trends_alt.do   // Alt employment trends — cut
*do ${code}04_appA_fig_spec_curve_reported.do  // Spec curves (reported) — cut

** -----------------------------------------------------------------------------
** Helper files (not directly called — sourced by 04_appE_inference.do)
** -----------------------------------------------------------------------------
*do ${code}04_appE_inference_programs.do
*do ${code}04_appE_inference_parallel.do
*do ${code}04_appE_inference_worker.do


** End log file
capture log close
