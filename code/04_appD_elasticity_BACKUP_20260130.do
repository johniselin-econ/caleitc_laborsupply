/*******************************************************************************
File Name:      04_appD_elasticity.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix D elasticity calculations
                Calculates participation and mobility elasticities based on
                CalEITC treatment effects.

                ELASTICITY FORMULA:
                E = (deltaP / P) / (delta(1-atr) / (1-atr))
                where:
                - deltaP = DiD coefficient = percentage point change in var
                - P = Percent of sample employed, treated, pre-period
                - delta(1-atr) = DiD coefficient = pp change in after-tax rate
                - 1-atr = mean of 1 - average tax rate, treated, pre-period

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appD_elasticity
log using "${logs}04_appD_elasticity_log_${date}", ///
    name(log_04_appD_elasticity) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define control variables
local controls "education age_bracket minage_qc race_group hispanic hh_adult_ct"

** Define cluster variable
local clustervar "state_fips"

** Base fixed effects
local did "qc_ct year state_fips"
local did "`did' state_fips#year"
local did "`did' state_fips#qc_ct"
local did "`did' year#qc_ct"

** Unemployment and minimum wage interactions
local unemp_mw "c.state_unemp#i.qc_ct c.minwage#i.qc_ct"

** =============================================================================
** STEP 1: Load data and setup
** =============================================================================

** Load data, restricted to sample
use if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        inrange(age, 20, 50) & ///
        citizen_test == 1 & ///
        inrange(year, 2012, 2017) ///
    using "${data}final/acs_working_file.dta", replace

** Keep if in low-education sample
keep if education <= 3

** Keep if in sample (California or control states)
keep if state_status > 0

** Create main DID variables
gen ca = (state_fips == 6)
gen childXyearXca = cond(qc_present == 1 & ca == 1, year, 2014)
gen treated = (state_fips == 6 & qc_present == 1 & year >= 2015)
gen post = (year >= 2015)
label var treated "Treated"

** Create minimum wage variable
gen minwage = mean_st_mw
label var minwage "Binding State Minimum Wage"

** Label ATR variable
label var taxsim_sim3_atr_st "After-tax rate at CalEITC Kink Point"

** =============================================================================
** STEP 2: Calculate participation elasticity (NW to PT)
** =============================================================================

di "PARTICIPATION ELASTICITY CALCULATIONS"

** Get baseline ATR (1-atr) at CalEITC kink point in pre-period
qui summ taxsim_sim3_atr_st if ///
    qc_present == 1 & ca == 1 & post == 0 ///
    [aw = weight]
local tauc1_pre_cal = `r(mean)'
di "Baseline ATR (pre-period, treated): `tauc1_pre_cal'"

** Get change in ATR from DiD
qui reghdfe taxsim_sim3_atr_st treated [aw = weight], ///
    absorb(`did') ///
    vce(cluster `clustervar')
local dtauc1_cal = (-1) * _b[treated]
di "Change in ATR from DiD: `dtauc1_cal'"

** Calculate denominator for elasticity
local denominator_cal = (`dtauc1_cal') / (1 - `tauc1_pre_cal')
di "Denominator (change in net-of-tax rate): `denominator_cal'"

** Get baseline part-time employment rate (P)
qui summ part_time_y if ///
    qc_present == 1 & ca == 1 & post == 0 ///
    [aw = weight]
local P = `r(mean)'
di "Baseline part-time employment rate (P): `P'"

** Get change in part-time employment from DiD (with controls)
qui reghdfe part_time_y treated `unemp_mw' [aw = weight], ///
    absorb(`did' `controls') ///
    vce(cluster `clustervar')
local beta = _b[treated]
di "Change in part-time employment (beta): `beta'"

** Calculate participation elasticity (assuming all NW to PT)
margins, expression((_b[treated] / `P') / (`denominator_cal')) post
mat r = r(table)
local part_e_all_nw_pt = r[1,1]
di _n "Participation Elasticity (all NW to PT): `part_e_all_nw_pt'"

** =============================================================================
** STEP 3: Calculate adjusted participation elasticity (FT to PT)
** =============================================================================

** Estimate full-time effect
qui reghdfe full_time_y treated `unemp_mw' [aw = weight], ///
    absorb(`did' `controls') ///
    vce(cluster `clustervar')
local beta_ft = _b[treated]

** Adjusted beta (accounting for FT to PT transitions)
local adjusted1_beta = max(`beta' + `beta_ft', 0)
di "Adjusted beta (FT to PT): `adjusted1_beta'"

local part_e_all_ft_pt = (`adjusted1_beta' / `P') / `denominator_cal'
di "Participation Elasticity (FT to PT adjustment): `part_e_all_ft_pt'"

** =============================================================================
** STEP 4: Calculate elasticity using $27K earnings bin
** =============================================================================

** Generate CPI adjusted values
qui summ cpi99 if year == 2017
local cpi_17 = r(mean)
replace incearn = incearn * (cpi99 / `cpi_17')

** Generate full-time at $27K indicator
gen full_time_27 = (full_time_y == 1 & inrange(incearn, 24001, 30000))

** Estimate full-time effect in $27K bin
qui reghdfe full_time_27 treated `unemp_mw' [aw = weight], ///
    absorb(`did' `controls') ///
    vce(cluster `clustervar')
local beta_ft_27 = _b[treated]

** Adjusted elasticity
local adjusted2_beta = max(`beta' + `beta_ft_27', 0)
di "Adjusted beta ($27K bin): `adjusted2_beta'"

local part_e_adj = (`adjusted2_beta' / `P') / `denominator_cal'
di "Participation Elasticity ($27K bin adjustment): `part_e_adj'"

** =============================================================================
** STEP 5: Calculate mobility elasticities using TAXSIM
** =============================================================================

di _n "=" * 70
di "MOBILITY ELASTICITY CALCULATIONS"
di "=" * 70

** Load CalEITC max income/credit parameters
import excel using ///
    "${data}eitc_parameters/caleitc_max_inc_max_cred.xlsx", clear firstrow

** Rename variables
rename tax_year year
rename qc_ct depx

** Save as temporary file
tempfile eitc_max_inc_max_cred
save `eitc_max_inc_max_cred'
clear

** -----------------------------------------------------------------------------
** Load QC shares for 2017
** -----------------------------------------------------------------------------

use if  female == 1 & ///
        married == 0 & ///
        inrange(age, 20, 50) & ///
        in_school == 0 & ///
        citizen_test == 1 & ///
        education < 4 & ///
        inrange(year, 2010, 2017) & ///
        state_fips == 6 ///
    using "${data}final/acs_working_file.dta", replace

** Keep required variables and restrict to 2017
keep year qc_ct weight
keep if year == 2017
drop if qc_ct == 0

** Collapse to get QC shares
gen ct = 1
collapse (sum) ct [fw = weight], by(year qc_ct)
bysort year: egen total_ct = total(ct)
gen share = ct / total_ct
rename qc_ct depx

** Save QC shares
tempfile qc_shares
save `qc_shares'
clear

** -----------------------------------------------------------------------------
** Create TAXSIM input file
** -----------------------------------------------------------------------------

** Create dataset with 4 observations (0-3 dependents)
set obs 4

** State (California = 5 in SOI codes)
gen state = 5

** Marital status (single)
gen mstat = 1

** Age of primary and secondary filers
gen page = 30
gen sage = 0

** Number of dependents (0-3)
gen depx = _n - 1

** Generate age of children (mechanism to assign QC)
gen age1 = 0
gen age2 = 0
gen age3 = 0
replace age1 = 6 if depx > 0
replace age2 = 6 if depx > 1
replace age3 = 6 if depx > 2

** Create two versions: 2014 and 2017
expand 2
bysort depx: gen year = 2014 + (_n - 1) * 3

** Merge with CalEITC max points
merge m:1 year depx using `eitc_max_inc_max_cred'
tab year _merge
keep if _merge == 3
drop _merge
rename pwages pwages_actual

** Create three wage scenarios:
** 1. Part-time at CalEITC Max
** 2. Full-time at 2017 minimum wage
** 3. Full-time at observed spike ($27K)
expand 3
bysort depx year: gen work = _n

** Set wage levels (baseline = no work)
gen pwages = 0

** Type 1: CalEITC Max
replace pwages = pwages_actual if work == 1 & year == 2017
replace pwages = pwages_unadj if work == 1 & year == 2014

** Type 2: 2017 Minimum Wage ($10.50/hr * 40 hrs * 52 weeks)
replace pwages = 52 * 10.5 * 40 if work == 2 & year == 2017
replace pwages = 52 * 10.5 * 40 if work == 2 & year == 2014

** Type 3: $27,000
replace pwages = 27000 if work == 3 & year == 2017
replace pwages = 27000 if work == 3 & year == 2014

** Generate ID for TAXSIM
gen taxsimid = _n
label var taxsimid "ID for taxsim"

** Save pre-TAXSIM file
tempfile prerun
save `prerun'

** Keep variables for TAXSIM
keep taxsimid year state mstat page depx age* pwages

** -----------------------------------------------------------------------------
** Run TAXSIM
** -----------------------------------------------------------------------------

** Change working directory for TAXSIM
cd "${data}taxsim"

** Run TAXSIM
taxsimlocal35, full
clear

** Load results
import delimited results.raw, clear

** Revert working directory
cd "${dir}"

** Clean up
destring taxsimid, replace
drop if missing(taxsimid)

** Keep variables to compute average tax rate
keep taxsimid fiitax siitax fica v10
rename v10 w
gen t = (fiitax + siitax + fica)

** Merge with original data
merge 1:1 taxsimid using `prerun', nogen

** Keep required variables
keep work year depx w t

** Generate net-of-tax earnings
gen n = w - t

** Reshape to wide format
reshape wide t w n, i(depx work) j(year)
rename t* t_*_
rename w* w_*_
rename n* n_*_
rename w_ork_ work
reshape wide t_* w_* n_*, i(depx) j(work)

** Merge with QC shares
merge m:1 depx using `qc_shares', nogen

** -----------------------------------------------------------------------------
** Calculate mobility elasticities
** -----------------------------------------------------------------------------

** Generate numerator
gen numerator_all = ln(`P' + `beta') - ln(`P')
gen numerator_partial = ln(`P' + abs(`beta_ft_27')) - ln(`P')

** Log net-of-tax earnings differences
gen denominator_1 = ln(abs(n_2017_1 - n_2017_2)) - ln(abs(n_2014_1 - n_2014_2))
gen denominator_2 = ln(abs(n_2017_1 - n_2017_3)) - ln(abs(n_2014_1 - n_2014_3))

** Generate mobility elasticity (assuming full effect is FT to PT)
gen elasticity_1_all = numerator_all / denominator_1
gen elasticity_2_all = numerator_all / denominator_2
gen elasticity_1_partial = numerator_partial / denominator_1
gen elasticity_2_partial = numerator_partial / denominator_2

** Display results by number of dependents
di _n "Mobility Elasticities (All effect):"
table depx [aw = share], stat(mean elasticity_*_all)

di _n "Mobility Elasticities (Partial effect):"
table depx [aw = share], stat(mean elasticity_*_partial)

** =============================================================================
** End
** =============================================================================

clear
log close log_04_appD_elasticity
