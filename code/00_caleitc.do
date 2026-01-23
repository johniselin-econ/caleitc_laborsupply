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
* ssc install ftools
* ssc install reghdfe
* ssc install ppmlhdfe
* ssc install fre
* ssc install coefplot
* ssc install estout
* ssc install gtools
* ssc install balancetable

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

** Load utility programs
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

rcall script "${code}R/01_data_prep_other.R", ///
    args( dir_data_raw   <- "${data}raw"; ///
          dir_data_int   <- "${data}interim"; ///
          start_year_data<- ${start_year_data}; ///
          end_year_data  <- ${end_year_data}; ///
          overwrite_bls  <- `overwrite_bls' ///
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

** Descriptive Statistics
do ${code}02_descriptives.do

** =============================================================================
** (03) PAPER TABLES AND FIGURES
** =============================================================================

** Figure: Federal and California EITC benefits schedule
do ${code}03_fig_eitc_sched.do

** Figure: Histogram of workers by full/part-time status
do ${code}03_fig_earn_hist.do

** Figure: Budget constraint for parent with 2 QC
do ${code}03_fig_budget.do

** Figure: Full-time and part-time employment trends
do ${code}03_fig_emp_trends.do

** Figure: Event-study estimates of CalEITC on employment
do ${code}03_fig_event_emp.do

** Figure: Effect by annual weeks of work
do ${code}03_fig_weeks.do

** Figure: Event-study estimates of CalEITC on earnings (PPML)
do ${code}03_fig_event_earn.do

** Figure: Specification curves over sample and controls
do ${code}03_fig_spec_curve.do

** Figure: Event-study estimates of the CalEITC on earnings 
do ${code}03_fig_event_earn.do

** Table: Triple-difference estimates on annual employment (main results)
do ${code}03_tab_main.do

** Table: Triple-difference estimates on intensive margin (hours, weeks, weekly emp)
do ${code}03_tab_intensive.do

** Table: Triple-difference by count of qualifying children
do ${code}03_tab_het_qc.do

** Table: Triple-difference by count of adults in HH
do ${code}03_tab_het_adults.do

** Table: Triple-difference estimates on annual earnings (OLS and PPML)
do ${code}03_tab_earnings.do

** Table: Triple-difference estimates on household income (OLS and PPML)
do ${code}03_tab_hh_earn.do

** =============================================================================
** (03B) SYNTHETIC DID ANALYSIS
** =============================================================================

** SDID Table 1: State Panel Synthetic DID Estimates (with event study)
do ${code}03_sdid_state.do

** SDID Table 2: County Panel Weighted SDID Estimates
do ${code}03_sdid_county.do

** =============================================================================
** (04) APPENDIX MATERIAL
** =============================================================================

** Appendix Table 1: Descriptive statistics
do ${code}04_appA_tab1.do

** Additional appendix figures and tables
do ${code}04_appendix.do

** End log file
capture log close

