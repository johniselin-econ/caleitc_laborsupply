/*******************************************************************************
File Name:      02b_caleitc_param_gen.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Programmatically create CalEITC max income/credit parameters
                by tax year and qualifying children count.

                For pre-2015 years (before CalEITC), deflates 2015 parameters
                using CPI-U-RS to provide counterfactual kink points.

Outputs:
- caleitc_max_inc_max_cred.xlsx: CalEITC kink point by year and QC count
  Variables: tax_year, qc_ct, pwages (CPI-adjusted), pwages_unadj (nominal)

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_02b
log using "${logs}02b_caleitc_param_gen_${date}", name(log_02b) replace text

** =============================================================================
** STEP 1: Define CalEITC parameters by year and QC count
** =============================================================================

** CalEITC max earned income (kink point where phase-out begins)
** Source: California Franchise Tax Board publications

clear

** Create dataset for years 2010-2017 and QC 0-3
** Note: CalEITC started in 2015 with QC >= 1
** For 2018, childless filers became eligible at 0.085 phase-in

** Years: 2010-2017 (8 years) x QC: 0-3 (4 levels) = 32 obs
set obs 32

** Generate year and QC combinations
gen tax_year = 2010 + floor((_n - 1) / 4)
gen qc_ct = mod(_n - 1, 4)

** =============================================================================
** CalEITC Max Earned Income Parameters (kink points)
** Source: FTB 3514 instructions by year
** =============================================================================

** Initialize variables
gen double pwages_nominal = .
gen double max_credit = .
gen double max_income = .
gen double phasein_rate = .
gen double phaseout_rate = .

** -----------------------------------------------------------------------------
** TY 2015 CalEITC Parameters (First year)
** Max earned income = $6,580; Max total income = $6,580 (very restricted)
** Note: QC=0 not eligible until 2018
** -----------------------------------------------------------------------------

** QC = 0: Not eligible
replace pwages_nominal = 0 if tax_year == 2015 & qc_ct == 0
replace max_credit = 0 if tax_year == 2015 & qc_ct == 0

** QC = 1
replace pwages_nominal = 2500 if tax_year == 2015 & qc_ct == 1
replace max_credit = 380 if tax_year == 2015 & qc_ct == 1
replace phasein_rate = 0.152 if tax_year == 2015 & qc_ct == 1
replace phaseout_rate = 0.058 if tax_year == 2015 & qc_ct == 1

** QC = 2
replace pwages_nominal = 3500 if tax_year == 2015 & qc_ct == 2
replace max_credit = 627 if tax_year == 2015 & qc_ct == 2
replace phasein_rate = 0.179 if tax_year == 2015 & qc_ct == 2
replace phaseout_rate = 0.096 if tax_year == 2015 & qc_ct == 2

** QC = 3+
replace pwages_nominal = 3500 if tax_year == 2015 & qc_ct == 3
replace max_credit = 705 if tax_year == 2015 & qc_ct == 3
replace phasein_rate = 0.201 if tax_year == 2015 & qc_ct == 3
replace phaseout_rate = 0.108 if tax_year == 2015 & qc_ct == 3

** 2015 max income for all QC >= 1
replace max_income = 6580 if tax_year == 2015 & qc_ct >= 1
replace max_income = 0 if tax_year == 2015 & qc_ct == 0

** -----------------------------------------------------------------------------
** TY 2016 CalEITC Parameters (Expanded)
** Max total income = $13,870
** Source: FTB 3514 (2016)
** -----------------------------------------------------------------------------

** QC = 0: Not eligible
replace pwages_nominal = 0 if tax_year == 2016 & qc_ct == 0
replace max_credit = 0 if tax_year == 2016 & qc_ct == 0

** QC = 1
replace pwages_nominal = 5089 if tax_year == 2016 & qc_ct == 1
replace max_credit = 865 if tax_year == 2016 & qc_ct == 1
replace phasein_rate = 0.17 if tax_year == 2016 & qc_ct == 1
replace phaseout_rate = 0.0799 if tax_year == 2016 & qc_ct == 1

** QC = 2
replace pwages_nominal = 7145 if tax_year == 2016 & qc_ct == 2
replace max_credit = 1429 if tax_year == 2016 & qc_ct == 2
replace phasein_rate = 0.20 if tax_year == 2016 & qc_ct == 2
replace phaseout_rate = 0.1053 if tax_year == 2016 & qc_ct == 2

** QC = 3+
replace pwages_nominal = 7145 if tax_year == 2016 & qc_ct == 3
replace max_credit = 1607 if tax_year == 2016 & qc_ct == 3
replace phasein_rate = 0.225 if tax_year == 2016 & qc_ct == 3
replace phaseout_rate = 0.1053 if tax_year == 2016 & qc_ct == 3

** 2016 max income
replace max_income = 13870 if tax_year == 2016 & qc_ct >= 1
replace max_income = 0 if tax_year == 2016 & qc_ct == 0

** -----------------------------------------------------------------------------
** TY 2017 CalEITC Parameters (Further Expanded)
** Max total income = $15,009
** Source: FTB 3514 (2017)
** -----------------------------------------------------------------------------

** QC = 0: Not eligible
replace pwages_nominal = 0 if tax_year == 2017 & qc_ct == 0
replace max_credit = 0 if tax_year == 2017 & qc_ct == 0

** QC = 1
replace pwages_nominal = 5189 if tax_year == 2017 & qc_ct == 1
replace max_credit = 882 if tax_year == 2017 & qc_ct == 1
replace phasein_rate = 0.17 if tax_year == 2017 & qc_ct == 1
replace phaseout_rate = 0.0799 if tax_year == 2017 & qc_ct == 1

** QC = 2
replace pwages_nominal = 7286 if tax_year == 2017 & qc_ct == 2
replace max_credit = 1457 if tax_year == 2017 & qc_ct == 2
replace phasein_rate = 0.20 if tax_year == 2017 & qc_ct == 2
replace phaseout_rate = 0.1053 if tax_year == 2017 & qc_ct == 2

** QC = 3+
replace pwages_nominal = 7286 if tax_year == 2017 & qc_ct == 3
replace max_credit = 1639 if tax_year == 2017 & qc_ct == 3
replace phasein_rate = 0.225 if tax_year == 2017 & qc_ct == 3
replace phaseout_rate = 0.1053 if tax_year == 2017 & qc_ct == 3

** 2017 max income
replace max_income = 15009 if tax_year == 2017 & qc_ct >= 1
replace max_income = 0 if tax_year == 2017 & qc_ct == 0

** =============================================================================
** STEP 2: CPI-U-RS deflation for pre-2015 years
** =============================================================================

** CPI-U-RS Annual Averages (base year = 2017)
** Source: BLS CPI-U-RS
** Using 2017 as reference year for deflation

gen double cpi_urs = .
replace cpi_urs = 340.5 if tax_year == 2010
replace cpi_urs = 352.5 if tax_year == 2011
replace cpi_urs = 359.7 if tax_year == 2012
replace cpi_urs = 365.0 if tax_year == 2013
replace cpi_urs = 370.9 if tax_year == 2014
replace cpi_urs = 372.2 if tax_year == 2015
replace cpi_urs = 377.0 if tax_year == 2016
replace cpi_urs = 385.0 if tax_year == 2017

** Calculate deflation factor (relative to 2015, first CalEITC year)
gen double deflator = cpi_urs / 372.2

** For pre-2015 years: deflate 2015 kink points to that year's dollars
** This creates counterfactual kink points as if CalEITC existed earlier
forvalues y = 2010/2014 {
    forvalues q = 1/3 {
        ** Get 2015 nominal value for this QC
        summ pwages_nominal if tax_year == 2015 & qc_ct == `q', meanonly
        local wage_2015 = r(mean)

        ** Get deflator for this year
        summ deflator if tax_year == `y', meanonly
        local def = r(mean)

        ** Set deflated value
        replace pwages_nominal = `wage_2015' * `def' if tax_year == `y' & qc_ct == `q'

        ** Also deflate max credit and max income
        summ max_credit if tax_year == 2015 & qc_ct == `q', meanonly
        replace max_credit = r(mean) * `def' if tax_year == `y' & qc_ct == `q'

        summ max_income if tax_year == 2015 & qc_ct == `q', meanonly
        replace max_income = r(mean) * `def' if tax_year == `y' & qc_ct == `q'

        ** Copy phase-in/out rates from 2015
        summ phasein_rate if tax_year == 2015 & qc_ct == `q', meanonly
        replace phasein_rate = r(mean) if tax_year == `y' & qc_ct == `q'

        summ phaseout_rate if tax_year == 2015 & qc_ct == `q', meanonly
        replace phaseout_rate = r(mean) if tax_year == `y' & qc_ct == `q'
    }

    ** QC = 0 remains 0 for pre-2015
    replace pwages_nominal = 0 if tax_year == `y' & qc_ct == 0
    replace max_credit = 0 if tax_year == `y' & qc_ct == 0
    replace max_income = 0 if tax_year == `y' & qc_ct == 0
}

** =============================================================================
** STEP 3: Create final variables for elasticity calculation
** =============================================================================

** pwages = CPI-adjusted to 2017 dollars (for TAXSIM comparison)
** pwages_unadj = nominal (year-specific) dollars

** Adjust to 2017 dollars using CPI-U-RS
gen double pwages = pwages_nominal * (385.0 / cpi_urs)

** Keep unadjusted version
gen double pwages_unadj = pwages_nominal

** Round to whole dollars
replace pwages = round(pwages, 1)
replace pwages_unadj = round(pwages_unadj, 1)
replace max_credit = round(max_credit, 1)
replace max_income = round(max_income, 1)

** =============================================================================
** STEP 4: Label and export
** =============================================================================

** Label variables
label var tax_year "Tax year"
label var qc_ct "Number of qualifying children (0-3)"
label var pwages "CalEITC kink point (2017 dollars)"
label var pwages_unadj "CalEITC kink point (nominal dollars)"
label var max_credit "Maximum CalEITC (2017 dollars)"
label var max_income "Maximum income for CalEITC (2017 dollars)"
label var phasein_rate "Phase-in rate"
label var phaseout_rate "Phase-out rate"
label var cpi_urs "CPI-U-RS (annual average)"
label var deflator "Deflation factor (rel. to 2015)"

** Order variables
order tax_year qc_ct pwages pwages_unadj max_credit max_income ///
      phasein_rate phaseout_rate

** Sort
sort tax_year qc_ct

** Display summary
di _n "=" * 70
di "CalEITC Max Income Parameters by Year and QC Count"
di "=" * 70
list tax_year qc_ct pwages pwages_unadj max_credit max_income, sepby(tax_year)

** Export to Excel
export excel using "${data}eitc_parameters/caleitc_max_inc_max_cred.xlsx", ///
    firstrow(variables) replace

** Also save as Stata file
save "${data}eitc_parameters/caleitc_max_inc_max_cred.dta", replace

** =============================================================================
** STEP 5: Create benefit schedule for visualization
** =============================================================================

** Create a grid of earnings to calculate CalEITC benefit at each point
preserve

clear
set obs 201  // $0 to $20,000 in $100 increments
gen earnings = (_n - 1) * 100

** Expand for years 2015-2017 and QC 1-3
expand 3  // 3 years
bysort earnings: gen year = 2014 + _n
expand 3  // 3 QC levels
bysort earnings year: gen qc = _n

** Merge with parameters
rename year tax_year
rename qc qc_ct
merge m:1 tax_year qc_ct using "${data}eitc_parameters/caleitc_max_inc_max_cred.dta", ///
    keep(match) nogen

** Calculate CalEITC benefit
gen double caleitc = 0

** Phase-in region (earnings <= kink point)
replace caleitc = earnings * phasein_rate if earnings <= pwages_unadj

** Phase-out region (earnings > kink point and <= max income)
replace caleitc = max_credit - (earnings - pwages_unadj) * phaseout_rate ///
    if earnings > pwages_unadj & earnings <= max_income

** Zero beyond max income
replace caleitc = 0 if earnings > max_income

** Floor at zero
replace caleitc = max(0, caleitc)

** Round
replace caleitc = round(caleitc, 1)

** Keep and export for plotting
keep tax_year qc_ct earnings caleitc pwages_unadj max_credit max_income
order tax_year qc_ct earnings caleitc

export delimited using "${results}tables/caleitc_benefit_by_year_qc.csv", replace

restore

** =============================================================================
** End
** =============================================================================

di _n "CalEITC parameters created successfully!"
di "Output: ${data}eitc_parameters/caleitc_max_inc_max_cred.xlsx"

log close log_02b
