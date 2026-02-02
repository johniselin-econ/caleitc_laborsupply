/*******************************************************************************
File Name:      03_tab_sim_inst.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates simulated instrument results table
                Using TAXSIM-based simulated EITC (Simulation 2) as instrument
                for treatment effect estimation.

                The simulated instrument approach follows Gruber & Saez (2002)
                and uses cell-level predicted EITC benefits based on:
                - Year x State x QC count x Marital status x Education x Age x Sex

                Uses utility programs: run_triple_diff, add_spec_indicators,
                add_table_stats

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_tab_sim_inst
log using "${logs}03_tab_sim_inst_log_${date}", name(log_03_tab_sim_inst) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define outcome variables
local outcomes "employed_y full_time_y part_time_y"

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

** Load ACS data (includes simulated EITC variables)
use weight `outcomes' `controls' `unemp' `minwage' qc_* year ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status ///
    taxsim_sim2_fedeitc taxsim_sim2_steitc taxsim_sim2_wt ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", clear

** Create main DID variables
gen ca = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)
label var treated "ATE"

** Update adults per HH (cap at 3)
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** Create simulated instrument (CalEITC introduction indicator x simulated state EITC)
** For CA in post period: simulated state EITC captures variation in CalEITC generosity

** Construct simulated instrument from taxim variables 
replace taxsim_sim2_steitc = 0 if state_fips != 6 
replace taxsim_sim2_steitc = taxsim_sim2_steitc / 1000
egen sim_inst = wtmean(taxsim_sim2_steitc ), weight(taxsim_sim2_wt) by(year qc_ct state_fips)
label var sim_inst "Simulated CalEITC (1,000s USD)"


** =============================================================================
** Section 1: Descriptive Statistics on Simulated Instrument
** =============================================================================

di _n _dup(70)"="
di "SIMULATED INSTRUMENT DESCRIPTIVE STATISTICS"
di _dup(70)"="

di _n "Simulated State EITC by year and QC status:"
table year qc_present [aw = weight], stat(mean taxsim_sim2_steitc) stat(sd taxsim_sim2_steitc)

di _n "Simulated State EITC by year (CA only):"
table year if ca == 1 [aw = weight], stat(mean taxsim_sim2_steitc) stat(sd taxsim_sim2_steitc)

di _n "Simulated State EITC by QC count (CA, post period):"
table qc_ct if ca == 1 & post == 1 [aw = weight], stat(mean taxsim_sim2_steitc) stat(sd taxsim_sim2_steitc)

** =============================================================================
** Section 2: First Stage - Effect of Treatment on Simulated EITC
** =============================================================================

di _n _dup(70)"="
di "FIRST STAGE REGRESSIONS"
di _dup(70)"="

** First stage: Does treatment predict simulated EITC?
eststo fs_1: reghdfe taxsim_sim2_steitc treated [aw = weight], ///
    absorb(`did_base') vce(cluster `clustervar')

estadd local fe_did "Yes"
estadd local controls "No"
estadd scalar fstat = e(F)

** With controls
eststo fs_2: reghdfe taxsim_sim2_steitc treated i.(`controls') ///
    c.`unemp'#i.qc_ct c.`minwage'#i.qc_ct [aw = weight], ///
    absorb(`did_base') vce(cluster `clustervar')

estadd local fe_did "Yes"
estadd local controls "Yes"
estadd scalar fstat = e(F)

di _n "First stage coefficient (simulated state EITC on treated):"
estimates restore fs_1

di "  Spec 1 (no controls): " %8.2f _b[treated] " (SE: " %8.2f _se[treated] ")"
estimates restore fs_2

di "  Spec 2 (with controls): " %8.2f _b[treated] " (SE: " %8.2f _se[treated] ")"

** =============================================================================
** Section 3: Reduced Form - Direct Effect of Simulated EITC on Outcomes
** =============================================================================

di _n _dup(70)"="
di "REDUCED FORM REGRESSIONS"
di _dup(70)"="

** Local count
local ct = 1

** Clear stored values for reduced form
eststo clear

** Loop over outcome variables
foreach out of local outcomes {

    ** Scale outcome to percentage points
    replace `out' = `out' * 100

    ** Reduced form: Effect of simulated EITC on employment
    ** Spec 1: Basic triple-diff structure, using simulated EITC
    eststo rf_`out'_1: reghdfe `out' sim_inst [aw = weight], ///
        absorb(`did_base') vce(cluster `clustervar')

    estadd local fe_did "Yes"
    estadd local controls "No"

    ** Spec 2: Add demographic controls
    eststo rf_`out'_2: reghdfe `out' sim_inst i.(`controls') [aw = weight], ///
        absorb(`did_base') vce(cluster `clustervar')

    estadd local fe_did "Yes"
    estadd local controls "Demographic"

    ** Spec 3: Add unemployment controls
    eststo rf_`out'_3: reghdfe `out' sim_inst i.(`controls') ///
        c.`unemp'#i.qc_ct [aw = weight], ///
        absorb(`did_base') vce(cluster `clustervar')

    estadd local fe_did "Yes"
    estadd local controls "Demo + Unemp"

    ** Spec 4: Add minimum wage controls (full specification)
    eststo rf_`out'_4: reghdfe `out' sim_inst i.(`controls') ///
        c.`unemp'#i.qc_ct c.`minwage'#i.qc_ct [aw = weight], ///
        absorb(`did_base') vce(cluster `clustervar')

    estadd local fe_did "Yes"
    estadd local controls "Full"

    ** Store mean for later
    qui summ `out' if qc_present == 1 & ca == 1 & post == 0 [aw = weight]
    estadd scalar ymean = r(mean)

    ** Update count
    local ct = `ct' + 1
}

** =============================================================================
** Section 4: Export Reduced Form Tables
** =============================================================================

di _n _dup(70)"="
di "EXPORTING REDUCED FORM TABLES"
di _dup(70)"="

** Reset counter
local ct = 1

** Loop over outcomes for table export
foreach out of local outcomes {

    ** Define statistics to export
    local stats_list "N r2_a ymean fe_did controls"
    local stats_fmt "%9.0fc %9.3fc %9.1fc %9s %9s"

    ** Define statistics labels
    local stats_labels `" "  Observations" "'
    local stats_labels `" `stats_labels' "  Adj. R-Square" "'
    local stats_labels `" `stats_labels' "  Treated group mean (pre)" "'
    local stats_labels `" `stats_labels' "  Triple-Diff FEs" "'
    local stats_labels `" `stats_labels' "  Controls" "'

    ** Save table locally
    esttab rf_`out'_1 rf_`out'_2 rf_`out'_3 rf_`out'_4 using ///
        "${results}tables/tab_sim_inst_rf_`ct'.tex", ///
        booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
        stats(`stats_list', ///
            fmt("`stats_fmt'") ///
            labels(`stats_labels')) ///
        b(3) se(3) label order(sim_inst) keep(sim_inst) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        prehead("\\ \midrule")

    ** Save to Overleaf if enabled
    if ${overleaf} == 1 {
        esttab rf_`out'_1 rf_`out'_2 rf_`out'_3 rf_`out'_4 using ///
            "${ol_tab}tab_sim_inst_rf_`ct'.tex", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
            stats(`stats_list', ///
                fmt("`stats_fmt'") ///
                labels(`stats_labels')) ///
            b(3) se(3) label order(sim_inst) keep(sim_inst) ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("\\ \midrule")
    }

    ** Update count
    local ct = `ct' + 1
}

** =============================================================================
** Section 5: IV Estimation (2SLS)
** =============================================================================

di _n _dup(70)"="
di "IV/2SLS ESTIMATION"
di _dup(70)"="

** Reload data to reset outcome scaling
use weight `outcomes' `controls' `unemp' `minwage' qc_* year ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status ///
    taxsim_sim2_fedeitc taxsim_sim2_steitc taxsim_sim2_wt ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        state_status > 0 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", clear

** Create variables
gen ca = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)
replace hh_adult_ct = 3 if hh_adult_ct > 3
gen sim_inst = ca * post * taxsim_sim2_steitc

** Clear estimates
eststo clear

** Reset counter
local ct = 1

** Loop over outcomes
foreach out of local outcomes {

    ** Scale to percentage points
    replace `out' = `out' * 100

    ** IV estimation using simulated EITC as instrument for treated
    ** Full specification with all controls
    eststo iv_`out': ivreghdfe `out' i.(`controls') ///
        (treated = sim_inst) [aw = weight], ///
        absorb(`did_base') cluster(`clustervar')

    ** Store statistics
    estadd local fe_did "Yes"
    estadd local controls "Full"
    estadd scalar fstat_first = e(widstat)

    ** Baseline mean
    qui summ `out' if qc_present == 1 & ca == 1 & post == 0 [aw = weight]
    estadd scalar ymean = r(mean)

    ** Update count
    local ct = `ct' + 1
}

** Export IV results table
local stats_list "N ymean fstat_first fe_did controls"
local stats_fmt "%9.0fc %9.1fc %9.1fc %9s %9s"

local stats_labels `" "  Observations" "'
local stats_labels `" `stats_labels' "  Treated group mean (pre)" "'
local stats_labels `" `stats_labels' "  First-stage F-stat" "'
local stats_labels `" `stats_labels' "  Triple-Diff FEs" "'
local stats_labels `" `stats_labels' "  Controls" "'

esttab iv_employed_y iv_full_time_y iv_part_time_y using ///
    "${results}tables/tab_sim_inst_iv.tex", ///
    booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
    stats(`stats_list', ///
        fmt("`stats_fmt'") ///
        labels(`stats_labels')) ///
    b(2) se(2) label order(treated) keep(treated) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    prehead("\\ \midrule")

if ${overleaf} == 1 {
    esttab iv_employed_y iv_full_time_y iv_part_time_y using ///
        "${ol_tab}tab_sim_inst_iv.tex", ///
        booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
        stats(`stats_list', ///
            fmt("`stats_fmt'") ///
            labels(`stats_labels')) ///
        b(2) se(2) label order(treated) keep(treated) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        prehead("\\ \midrule")
}

** =============================================================================
** Section 6: Summary of Results
** =============================================================================

di _n _dup(70)"="
di "SUMMARY OF SIMULATED INSTRUMENT RESULTS"
di _dup(70)"="

di _n "The simulated instrument approach uses cell-level predicted CalEITC"
di "based on tax policy parameters and demographic characteristics."
di ""
di "Key findings:"

** Display IV coefficients
foreach out in employed_y full_time_y part_time_y {
    estimates restore iv_`out'
    di "  `out': " %6.3f _b[treated] " (SE: " %6.3f _se[treated] ")"
}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_tab_sim_inst
