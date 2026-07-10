/*******************************************************************************
File Name:      02_eitc_param_prep.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Prepare EITC schedule parameters for CalEITC analysis
                Creates benefit schedules for federal and California EITC

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_02_eitc
log using "${logs}02_log_eitc_prep_${date}", name(log_02_eitc) replace text

** =============================================================================
** Create EITC Schedule Data
** =============================================================================

** Federal EITC parameters for 2015-2017 (example for TY 2016)
** Source: IRS Publication 596

clear
set obs 4

gen qc = _n - 1  // 0, 1, 2, 3 qualifying children

** TY 2016 Federal EITC parameters
gen ty = 2016

** Phase-in rate
gen phasein_rate = .
replace phasein_rate = 0.0765 if qc == 0
replace phasein_rate = 0.34 if qc == 1
replace phasein_rate = 0.40 if qc == 2
replace phasein_rate = 0.45 if qc == 3

** Maximum earned income for max credit
gen max_earned = .
replace max_earned = 6610 if qc == 0
replace max_earned = 10180 if qc == 1
replace max_earned = 14290 if qc == 2
replace max_earned = 14290 if qc == 3

** Maximum credit
gen max_credit = .
replace max_credit = 506 if qc == 0
replace max_credit = 3373 if qc == 1
replace max_credit = 5572 if qc == 2
replace max_credit = 6269 if qc == 3

** Plateau end (phase-out begins)
gen plateau_end = .
replace plateau_end = 8270 if qc == 0
replace plateau_end = 18190 if qc >= 1

** Phase-out rate
gen phaseout_rate = .
replace phaseout_rate = 0.0765 if qc == 0
replace phaseout_rate = 0.1598 if qc == 1
replace phaseout_rate = 0.2106 if qc == 2
replace phaseout_rate = 0.2106 if qc == 3

** Maximum income (credit = 0)
gen max_income = .
replace max_income = 14880 if qc == 0
replace max_income = 39296 if qc == 1
replace max_income = 44648 if qc == 2
replace max_income = 47955 if qc == 3

** Label variables
label var qc "Number of qualifying children"
label var ty "Tax year"
label var phasein_rate "Phase-in rate"
label var max_earned "Max earned income for max credit"
label var max_credit "Maximum credit"
label var plateau_end "Income where phase-out begins"
label var phaseout_rate "Phase-out rate"
label var max_income "Maximum income for any credit"

save "${data}interim/eitc_federal_2016.dta", replace

** =============================================================================
** CalEITC Parameters (TY 2016)
** =============================================================================

clear
set obs 3

gen qc = _n  // 1, 2, 3 qualifying children (no credit for 0 QC in 2016)

** TY 2016 CalEITC parameters
gen ty = 2016

** Phase-in rate (50% of federal)
gen phasein_rate = .
replace phasein_rate = 0.17 if qc == 1
replace phasein_rate = 0.20 if qc == 2
replace phasein_rate = 0.225 if qc == 3

** Maximum earned income for max credit (CalEITC limit: $13,870 in 2016)
gen max_earned = .
replace max_earned = 5089 if qc == 1
replace max_earned = 7145 if qc == 2
replace max_earned = 7145 if qc == 3

** Maximum credit (50% of federal max)
gen max_credit = .
replace max_credit = 865 if qc == 1
replace max_credit = 1429 if qc == 2
replace max_credit = 1607 if qc == 3

** Phase-out begins at max earned
gen plateau_end = max_earned

** Phase-out rate
gen phaseout_rate = .
replace phaseout_rate = 0.0799 if qc == 1
replace phaseout_rate = 0.1053 if qc == 2
replace phaseout_rate = 0.1053 if qc == 3

** Maximum income (CalEITC cutoff)
gen max_income = 13870

label var qc "Number of qualifying children"
label var ty "Tax year"
label var phasein_rate "Phase-in rate"
label var max_earned "Max earned income for max credit"
label var max_credit "Maximum credit"
label var plateau_end "Income where phase-out begins"
label var phaseout_rate "Phase-out rate"
label var max_income "Maximum income for any credit"

save "${data}interim/eitc_california_2016.dta", replace

** =============================================================================
** Create earnings grid for benefit calculation
** =============================================================================

clear
set obs 501
gen earnings = (_n - 1) * 100  // $0 to $50,000 in $100 increments

** Calculate federal EITC by QC count
forvalues q = 0/3 {

    ** Phase-in rate
    if `q' == 0 local pi_rate = 0.0765
    if `q' == 1 local pi_rate = 0.34
    if `q' == 2 local pi_rate = 0.40
    if `q' == 3 local pi_rate = 0.45

    ** Max earned for max credit
    if `q' == 0 local max_e = 6610
    if `q' == 1 local max_e = 10180
    if `q' == 2 local max_e = 14290
    if `q' == 3 local max_e = 14290

    ** Maximum credit
    if `q' == 0 local max_c = 506
    if `q' == 1 local max_c = 3373
    if `q' == 2 local max_c = 5572
    if `q' == 3 local max_c = 6269

    ** Plateau end
    if `q' == 0 local plat_end = 8270
    if `q' >= 1 local plat_end = 18190

    ** Phase-out rate
    if `q' == 0 local po_rate = 0.0765
    if `q' == 1 local po_rate = 0.1598
    if `q' == 2 local po_rate = 0.2106
    if `q' == 3 local po_rate = 0.2106

    ** Calculate benefit
    gen fed_eitc_`q' = 0

    ** Phase-in region
    replace fed_eitc_`q' = earnings * `pi_rate' if earnings <= `max_e'

    ** Plateau region
    replace fed_eitc_`q' = `max_c' if earnings > `max_e' & earnings <= `plat_end'

    ** Phase-out region
    replace fed_eitc_`q' = max(0, `max_c' - (earnings - `plat_end') * `po_rate') ///
        if earnings > `plat_end'

}

** Calculate CalEITC by QC count (1-3 only, no credit for 0 QC in 2016)
forvalues q = 1/3 {

    ** Phase-in rate
    if `q' == 1 local pi_rate = 0.17
    if `q' == 2 local pi_rate = 0.20
    if `q' == 3 local pi_rate = 0.225

    ** Max earned for max credit
    if `q' == 1 local max_e = 5089
    if `q' == 2 local max_e = 7145
    if `q' == 3 local max_e = 7145

    ** Maximum credit
    if `q' == 1 local max_c = 865
    if `q' == 2 local max_c = 1429
    if `q' == 3 local max_c = 1607

    ** Phase-out rate
    if `q' == 1 local po_rate = 0.0799
    if `q' == 2 local po_rate = 0.1053
    if `q' == 3 local po_rate = 0.1053

    ** Max income
    local max_inc = 13870

    ** Calculate benefit
    gen cal_eitc_`q' = 0

    ** Phase-in region
    replace cal_eitc_`q' = earnings * `pi_rate' if earnings <= `max_e'

    ** Phase-out region
    replace cal_eitc_`q' = max(0, `max_c' - (earnings - `max_e') * `po_rate') ///
        if earnings > `max_e' & earnings <= `max_inc'

}

** Combined credit for California
forvalues q = 1/3 {
    gen total_eitc_`q' = fed_eitc_`q' + cal_eitc_`q'
}

** Save
save "${data}interim/eitc_benefit_schedule.dta", replace

** Export for R plotting
export delimited "${results}tables/eitc_benefit_schedule.csv", replace

** =============================================================================
** End
** =============================================================================

log close log_02_eitc
