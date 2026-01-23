/*******************************************************************************
File Name:      04_appA_tab1.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix Table 1
                Descriptive statistics, single women aged 20-50 without
                a college degree via the ACS

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_tab1
log using "${logs}04_appA_tab1_log_${date}", name(log_04_appA_tab1) replace text

** =============================================================================
** Load data
** =============================================================================

** Load ACS data
use if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        inrange(age, 20, 50) & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, ${start_year}, ${end_year}) ///
    using ${data}final/acs_working_file, clear

** =============================================================================
** Generate splitting variables
** =============================================================================

** Generate splitting variables based on treatment (QC & CA) and time (pre/post)
gen byvar1 = year < 2015 & qc_present == 0 & state_fips == 6
gen byvar2 = year < 2015 & qc_present == 1 & state_fips == 6
gen byvar3 = year >= 2015 & qc_present == 0 & state_fips == 6
gen byvar4 = year >= 2015 & qc_present == 1 & state_fips == 6
gen byvar5 = year < 2015 & qc_present == 0 & state_fips != 6
gen byvar6 = year < 2015 & qc_present == 1 & state_fips != 6
gen byvar7 = year >= 2015 & qc_present == 0 & state_fips != 6
gen byvar8 = year >= 2015 & qc_present == 1 & state_fips != 6

** =============================================================================
** Generate required variables
** =============================================================================

** Generate race variables
tabulate race_hisp, generate(race)
tabulate education, gen(educ)

** Fix labels
label var race1 "Hispanic"
label var race2 "Non-Hispanic White"
label var race3 "Non-Hispanic Black"
label var race4 "Non-Hispanic Other"
label var educ1 "No High School"
label var educ2 "High School Grad"
label var educ3 "Some College"
label var hh_adult_ct "Adults in HH"

** Adjust scale of variables to percentages
foreach var of varlist employed_y full_time_y part_time_y ///
    race1-race4 educ1-educ3 {

    replace `var' = `var' * 100

}

** =============================================================================
** Create summary statistics table
** =============================================================================

** Define variable list
local varlist ""
local varlist "`varlist' age hh_adult_ct"
local varlist "`varlist' race1 race2 race3 race4"
local varlist "`varlist' educ1 educ2 educ3"
local varlist "`varlist' employed_y"
local varlist "`varlist' full_time_y part_time_y"
local varlist "`varlist' hours_worked_y weeks_worked_y"
local varlist "`varlist' incearn_nom"

** Create Balance Table and save locally
balancetable (mean if byvar1==1) (mean if byvar2==1) ///
             (mean if byvar3==1) (mean if byvar4==1) ///
             (mean if byvar5==1) (mean if byvar6==1) ///
             (mean if byvar7==1) (mean if byvar8==1) ///
    `varlist' using "${results}paper/tab_appA_tab1.tex" [aw = weight], ///
    ctitles("No QC" "1+ QC" "No QC" "1+ QC" ///
            "No QC" "1+ QC" "No QC" "1+ QC" ) ///
    groups("CA - ${start_year}-2014" "CA - 2015-${end_year}" ///
           "Controls - ${start_year}-2014" "Controls - 2015-${end_year}", ///
           pattern(1 0  1 0 1 0  1 0) end("\cline{2-9}")) ///
    replace varlabels wrap(20 indent) nonumbers leftctitle("") format(%12.1fc)

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    balancetable (mean if byvar1==1) (mean if byvar2==1) ///
                 (mean if byvar3==1) (mean if byvar4==1) ///
                 (mean if byvar5==1) (mean if byvar6==1) ///
                 (mean if byvar7==1) (mean if byvar8==1) ///
        `varlist' using "${ol_tab}tab_appA_tab1.tex" [aw = weight], ///
        ctitles("No QC" "1+ QC" "No QC" "1+ QC" ///
                "No QC" "1+ QC" "No QC" "1+ QC" ) ///
        groups("CA - ${start_year}-2014" "CA - 2015-${end_year}" ///
               "Controls - ${start_year}-2014" "Controls - 2015-${end_year}", ///
               pattern(1 0  1 0 1 0  1 0) end("\cline{2-9}")) ///
        replace varlabels wrap(20 indent) nonumbers leftctitle("") format(%12.1fc)
}

** END
clear
log close log_04_appA_tab1
