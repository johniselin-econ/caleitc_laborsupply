/*******************************************************************************
File Name: 		00_caleitc.do
Creator: 		John Iselin
Date Update:	January 2026

Purpose: 	Runs the analysis on the labor supply effects of the CalEITC
			implementation in 2015

Authors: John Iselin

For more information, contact john.iselin@yale.edu

** TO-DO LIST
** 1) Run Data Prep via R (IPUMS API)
** 2) Clean Data in Stata
** 3) Run Triple-Difference Analysis
** 4) Generate Tables and Figures

*******************************************************************************/

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
global dir "C:/Users/ji252/Documents/GitHub/caleitc_laborsupply/"
global code 	"${dir}code/"				// CODE FILEPATH
global data 	"${dir}data/"				// DATA FILEPATH
global results 	"${dir}results/"			// RESULTS FILEPATH
global logs 	"${code}logs/"				// LOG FILE SUB-FILEPATH

** Set WD
cd ${dir}

** OVERLEAF FILE PATH (Update as needed)

global oth_path		///
	"C:/Users/ji252/Dropbox/Apps/Overleaf/CalEITC/"
global ol_fig 		"${oth_path}figures/"
global ol_tab		"${oth_path}tables/"

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
/*
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
*/
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
** (03) MAIN TEXT - TABLES AND FIGURES
** =============================================================================
** Organized by paper section to match manuscript structure

** -----------------------------------------------------------------------------
** Section 2.1: Federal and California EITC Structure
** -----------------------------------------------------------------------------

** Figure 1 (p.10): Federal and California EITC benefits schedule, TY 2016
do ${code}03_fig_eitc_sched.do

** Figure 2 (p.11): Histograms of California workers
do ${code}03_fig_earn_hist.do

** -----------------------------------------------------------------------------
** Section 3: Conceptual Framework
** -----------------------------------------------------------------------------

** Figure 3 (p.13): Budget constraint for parent with 2 qualifying children (QC) in 2016
do ${code}03_fig_budget.do

** -----------------------------------------------------------------------------
** Section 5.1: Trends
** -----------------------------------------------------------------------------

** Figure 4 (p.22): Full-time and part-time employment in the ACS
do ${code}03_fig_emp_trends.do

** -----------------------------------------------------------------------------
** Section 5.2: Primary Triple-Difference Results
** -----------------------------------------------------------------------------

** Table 1 (p.24): Triple-difference estimates of the effect of the CalEITC on annual employment
do ${code}03_tab_main.do

** Figure 5 (p.25): Event-study estimates of the effect of the CalEITC on annual employment
do ${code}03_fig_event_emp.do

** Figure 6 (p.27): Effect of the CalEITC on employment, by weekly hours worked
do ${code}03_fig_hours_bins.do

** Figure 7 (p.28): Effect of the CalEITC on employment, by annual weeks of work
do ${code}03_fig_weeks.do

** -----------------------------------------------------------------------------
** Section 5.4: Robustness
** -----------------------------------------------------------------------------

** Table 2 (p.30): Synthetic Difference-in-Differences estimates
do ${code}03_sdid_state.do

** Figure 8 (p.31): College-educated sample event-study (falsification test)
do ${code}03_fig_event_col_placebo.do

** Figure 9 (p.34): Specification curves
do ${code}03_fig_spec_curve.do

** -----------------------------------------------------------------------------
** Section 6: Annual Earnings
** -----------------------------------------------------------------------------

** Table 3 (p.38): Triple-difference estimates, effect of the CalEITC on annual earnings
do ${code}03_tab_earnings.do

** Figure 10 (p.39): Changes in the earnings distribution over time, CA vs control states
do ${code}03_fig_earn_bins.do

** -----------------------------------------------------------------------------
** Section 7.1: Heterogeneity by Number of Qualifying Children
** -----------------------------------------------------------------------------

** Figure 11 (p.45): Triple-difference employment effects, by number of qualifying children
do ${code}03_tab_het_qc.do

** -----------------------------------------------------------------------------
** Section 7.2: Heterogeneity by Number of Adults in Household
** -----------------------------------------------------------------------------

** Figure 12 (p.47): Triple-difference employment effects, by number of adults in household
do ${code}03_tab_het_adults.do

** -----------------------------------------------------------------------------
** Section 7.3: Heterogeneity by Age of Youngest Qualifying Child
** -----------------------------------------------------------------------------

** Figure 13 (p.48): Triple-difference employment effects, by age of youngest qualifying child
do ${code}03_tab_het_qc_age.do

** -----------------------------------------------------------------------------
** Section 7.4: Individual versus Household Income
** -----------------------------------------------------------------------------

** Figure 14 (p.50): Event-study estimates—mother's earnings vs household income
do ${code}03_fig_event_earn.do

** -----------------------------------------------------------------------------
** Section 8: MVPF and Fiscal Externalities
** -----------------------------------------------------------------------------

** Figure 15 (p.53): Distribution of Marginal Value of Public Funds estimates
do ${code}03_fig_mvpf_dist.do

** Figure 16 (p.55): Implied fiscal spillovers under different assumptions
do ${code}03_fig_mvpf_spillovers.do

** -----------------------------------------------------------------------------
** ** FUTURE WORK ** (Main text files not currently used in paper)
** -----------------------------------------------------------------------------
*do ${code}03_fig_treat_by_earn.do     // Treatment effects by earnings bins
*do ${code}03_tab_earn_hhcomp.do       // Earnings by household composition
*do ${code}03_tab_intensive.do         // Intensive margin (hours, weeks)
*do ${code}03_tab_sim_inst.do          // Simulated instrument results
*do ${code}03_tab_hh_earn.do           // Household income (OLS and PPML)
*do ${code}03_sdid_county.do           // County panel weighted SDID
*do ${code}03_tab_desc.do              // Deprecated - see 04_appA_tab1.do
*do ${code}02_descriptives.do          // Summary statistics (standalone)

** =============================================================================
** (04) APPENDIX MATERIAL
** =============================================================================

** =============================================================================
** APPENDIX A: Additional Tables and Figures
** =============================================================================

** Appendix Table A.1 (p.68): Sample states and population statistics
do ${code}04_appA_tab1.do

** Appendix Figure A.1 (p.69): Federal & CA EITC benefits schedule, TY 2015 and 2017
do ${code}04_appA_fig_eitc_sched_15_17.do

** Appendix Figure A.2 (p.70): EITC and CTC schedule by qualifying children (2016)
do ${code}04_appA_fig_eitc_ctc_sched.do

** Appendix Figure A.3 (p.71): Post-2017 changes to federal and state tax credits
do ${code}04_appA_fig_tcja_yctc.do

** Appendix Figure A.4 (p.72): State-level unemployment trends, 2005–2019
do ${code}04_appA_fig_unemp_trends.do

** Appendix Figure A.5 (p.73): Binding state minimum wages in control pool, 2010–2017
do ${code}04_appA_fig_minwage.do

** Appendix Figure A.6 (p.74): Triple-difference effect on the after-tax rate
do ${code}04_appA_fig_atr_event.do

** Appendix Table A.2-A.3 (p.75): Triple-difference balance test
do ${code}04_appA_tab_balance.do

** Appendix Table A.4 (p.76): Triple-difference estimates—college placebo test
do ${code}04_appA_tab_col_placebo.do

** -----------------------------------------------------------------------------
** ** FUTURE WORK ** (Appendix A files not currently used in paper)
** -----------------------------------------------------------------------------
*do ${code}04_appA_fig_spec_curve_reported.do  // Specification curves (reported hours/weeks)
*do ${code}04_appA_fig_emp_trends_alt.do       // Alternative employment trend thresholds
*do ${code}04_appA_tab_alt_threshold.do        // Alternative FT/PT threshold estimates

** =============================================================================
** APPENDIX B: Labor Supply Effects Among Other Populations
** =============================================================================

** Appendix Figures B.1-B.3 (p.78-80): Married women, Single men, Married men
do ${code}04_appB_otherpops.do

** =============================================================================
** APPENDIX C: Self-Employment
** =============================================================================

** Appendix Table C.1 (p.83): Employment effects conditional on reporting wage income
do ${code}04_appC_tab_wage_emp.do

** Appendix Table C.2 (p.84): Effects on self-employment
do ${code}04_appC_tab_self_emp.do

** Appendix Figure C.1 (p.85): Event-study (employment restricted to wage workers)
do ${code}04_appC_fig_wage_emp.do

** Appendix Figure C.2 (p.86): Event-study (annual self-employment)
do ${code}04_appC_fig_self_emp.do

** =============================================================================
** APPENDIX D: Inference
** =============================================================================

** Appendix Table D.1 (p.93): Triple-difference estimates with different inference procedures
do ${code}04_appE_inference.do

** -----------------------------------------------------------------------------
** ** FUTURE WORK ** (Appendix D/E helper files not directly called)
** -----------------------------------------------------------------------------
*do ${code}04_appE_inference_programs.do   // Programs for inference procedures
*do ${code}04_appE_inference_parallel.do   // Parallel bootstrap implementation
*do ${code}04_appE_inference_worker.do     // Worker file for parallel jobs
*do ${code}04_appendix.do                  // Empty appendix placeholder


** End log file
capture log close

