/*******************************************************************************
File Name:      03_tab_earn_hhcomp.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Table 5b
                Triple-difference estimates of the effect of the CalEITC
                on earnings by household composition (OLS and PPML)

                Columns:
                (1) Own earnings, full sample, all controls
                (2) Own earnings, single-adult HH only (hh_adult_ct == 1)
                (3) Other HH member earnings, multi-adult HH (hh_adult_ct >= 2)
                (4) Other HH member earnings, 3+ adult HH (hh_adult_ct >= 3)

                Rows: OLS (all), OLS (positive), PPML

                Uses utility programs: run_triple_diff, run_ppml_regression,
                add_spec_indicators, export_table_panel

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_tab_earn_hhcomp
log using "${logs}03_tab_earn_hhcomp_log_${date}", name(log_03_tab_earn_hhcomp) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define control variables
local controls "education age_bracket minage_qc race_group hispanic hh_adult_ct"

** Define unemployment control variable
local unemp "state_unemp"

** Define minimum wage control variable
local minwage "mean_st_mw"

** Define cluster variable
local clustervar "state_fips"

** Define start and end dates
local start = ${start_year}
local end = ${end_year}

** Base fixed effects
local did_base "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"

** =============================================================================
** Load data and define sample
** =============================================================================

** Load ACS data
use weight incearn_real inctot_hh_real `controls' `unemp' `minwage' qc_* year ///
    female married in_school age citizen_test state_fips state_status ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        inrange(age, 20, 50) & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using ${data}final/acs_working_file, clear

** Handle missing earned income
replace incearn_real = 0 if incearn_real == . 
replace inctot_hh_real = 0 if inctot_hh_real == . 

** Drop negatives 
drop if incearn_real < 0 
drop if inctot_hh_real < 0 
drop if incearn_real > inctot_hh_real 

** Create other HH member earnings (HH earnings minus own earnings)
gen inctot_other_real = inctot_hh_real - incearn_real
label var inctot_other_real "Other HH member earnings (real)"

** Create main DID variables
gen ca = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)
label var treated "ATE"

** Store original hh_adult_ct before capping for sample restrictions
gen hh_adult_ct_orig = hh_adult_ct

** Update adults per HH (cap at 3 for FE)
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** =============================================================================
** Define column specifications
** =============================================================================

** Column 1: Own earnings, full sample
local out1 "incearn_real"
local samp1 "1 == 1"
local lbl1 "Own Earnings (All)"

** Column 2: Own earnings, single-adult HH
local out2 "incearn_real"
local samp2 "hh_adult_ct_orig == 1"
local lbl2 "Own Earnings (1 Adult)"

** Column 3: Other HH earnings, multi-adult HH (2+ adults)
local out3 "inctot_other_real"
local samp3 "hh_adult_ct_orig >= 2"
local lbl3 "Other Income (2+ Adults)"

** Column 4: Other HH earnings, 3+ adult HH
local out4 "inctot_other_real"
local samp4 "hh_adult_ct_orig >= 3"
local lbl4 "Other Income (3+ Adults)"

** =============================================================================
** Run regressions and export tables
** =============================================================================

** Clear stored values
eststo clear

** Loop over models (1=OLS all, 2=OLS positive, 3=PPML)
forvalues m = 1/3 {

    ** Loop over columns (1-4)
    forvalues c = 1/4 {

        ** Get outcome and sample for this column
        local outcome "`out`c''"
        local samp_cond "`samp`c''"

        ** Define sample conditions based on model
        if `m' == 1 {
            ** OLS, all observations (including zeros)
            gen sample = `outcome' >= 0 & !missing(`outcome') & `samp_cond'
        }
        else if `m' == 2 {
            ** OLS, positive only
            gen sample = `outcome' > 0 & !missing(`outcome') & `samp_cond'
        }
        else if `m' == 3 {
            ** PPML (allows zeros)
            gen sample = `outcome' >= 0 & !missing(`outcome') & `samp_cond'
        }
		

        ** Run regression
        if `m' < 3 {
            ** OLS regression
            eststo est_`m'_`c': 						///
                run_triple_diff `outcome' if sample == 1, ///
                    treatvar(treated) ///
                    controls(`controls') ///
                    unempvar(`unemp') ///
                    minwagevar(`minwage') ///
                    fes(`did_base') ///
                    weightvar(weight) ///
                    clustervar(`clustervar') ///
                    qcvar(qc_ct)
        }
        else {
            ** PPML regression
            eststo est_`m'_`c': ///
                run_ppml_regression `outcome', ///
                    treatvar(treated) ///
                    controls(`controls') ///
                    unempvar(`unemp') ///
                    minwagevar(`minwage') ///
                    fes(`did_base') ///
                    weightvar(weight) ///
                    clustervar(`clustervar') ///
                    qcvar(qc_ct) ///
                    samplecond(sample == 1)
            estadd scalar AME = r(AME)
        }

        ** Get pre-period treated mean
        qui summ `outcome' if sample == 1 & post == 0 & ca == 1 & qc_present == 1 [aw=weight]
        estadd scalar ymean = r(mean)

        ** Drop sample variable
        drop sample

    }

    ** Define statistics and formatting for export
    if `m' < 3 {
        local stats_list "N r2_a ymean"
        local stats_fmt "%9.0fc %9.3fc %9.0fc"
        local stats_labels `" "Observations" "Adj. R-Square" "Treated group mean in pre-period" "'
        local dig = 1
    }
    else {
        local stats_list "N r2_p ymean AME"
        local stats_fmt "%9.0fc %9.3fc %9.0fc %9.0fc"
        local stats_labels `" "Observations" "Pseudo-R-squared" "Treated group mean in pre-period" "Effect in USD" "'
        local dig = 2
    }

    ** Export table for this model
    esttab est_`m'_1 est_`m'_2 est_`m'_3 est_`m'_4 using ///
        "${results}paper/tab_earn_hhcomp_`m'.tex", ///
        booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
        stats(`stats_list', ///
            fmt(`stats_fmt') ///
            labels(`stats_labels')) ///
        b(`dig') se(`dig') label order(treated) keep(treated) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        prehead("\\ \midrule")

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        esttab est_`m'_1 est_`m'_2 est_`m'_3 est_`m'_4 using ///
            "${ol_tab}tab_earn_hhcomp_`m'.tex", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
            stats(`stats_list', ///
                fmt(`stats_fmt') ///
                labels(`stats_labels')) ///
            b(`dig') se(`dig') label order(treated) keep(treated) ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("\\ \midrule")
    }

}

** =============================================================================
** Export column headers (for LaTeX table construction)
** =============================================================================

** Create a simple tex file with column headers
file open colhead using "${results}paper/tab_earn_hhcomp_colhead.tex", write replace
file write colhead "& `lbl1' & `lbl2' & `lbl3' & `lbl4' \\" _n
file close colhead

** =============================================================================
** End
** =============================================================================

clear
log close log_03_tab_earn_hhcomp
