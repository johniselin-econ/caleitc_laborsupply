/*******************************************************************************
File Name:      01_clean_data.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Clean and prepare ACS data for CalEITC analysis
                Following the data cleaning structure from 01_data_prep_ipums.R

                This do-file:
                - Imports ACS CSV files downloaded via R/api_code.R
                - Assigns qualifying children to adults (qc_assignment program)
                - Creates household composition variables
                - Creates demographic and employment variables
                - Merges with unemployment and minimum wage data
                - Assigns state treatment status

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_01
log using "${logs}01_log_data_clean_${date}", name(log_01) replace text

** =============================================================================
** (1) IMPORT BLS AND MINIMUM WAGE DATA
** =============================================================================

** Import state unemployment (created by R/01_data_prep_other.R)
import delimited "${data}interim/bls_state_unemployment_annual.csv", clear
rename value state_unemp
keep year state_fips state_unemp
save "${data}interim/st_unemp_year.dta", replace

** Import county unemployment
import delimited "${data}interim/bls_county_unemployment_annual.csv", clear
rename value county_unemp
destring state_fips, replace ignore("" "NA")
destring county_fips, replace ignore("" "NA")
keep year state_fips county_fips county_unemp
save "${data}interim/ct_unemp_year.dta", replace

** Import state minimum wage
import delimited "${data}interim/VKZ_state_minwage_annual.csv", clear
destring state_fips, replace ignore("" "NA")
rename state_minwage mean_st_mw
keep year state_fips mean_st_mw
save "${data}interim/st_minwage_year.dta", replace

** =============================================================================
** (2) CAPTURE 2015 CPI VALUE FOR SIMULATION 3
** =============================================================================

** Need 2015 CPI value for adjusting CalEITC parameters in earlier years
capture confirm file "${data}acs/acs_2015.csv"
if _rc == 0 {
    import delimited "${data}acs/acs_2015.csv", clear
    qui summ cpi99, meanonly
    global cpi_2015 = r(mean)
    dis "Captured 2015 CPI value: ${cpi_2015}"
    clear
}
else {
    ** Fallback to approximate value if 2015 file not found
    global cpi_2015 = 0.811
    dis "Using fallback 2015 CPI value: ${cpi_2015}"
}

** =============================================================================
** (3) LOOP OVER YEARS TO PROCESS ACS DATA
** =============================================================================

forvalues y = $end_year_data(-1)$start_year_data {

    dis ""
    dis "=============================================="
    dis "Processing ACS data for year `y'"
    dis "=============================================="

    ** Check if file exists
    capture confirm file "${data}acs/acs_`y'.csv"
    if _rc != 0 {
        dis "  File not found, skipping year `y'"
        continue
    }

    ** Import CSV
    import delimited "${data}acs/acs_`y'.csv", clear

    ** -------------------------------------------------------------------------
    ** Step 1: Pre-QC assignment data prep
    ** -------------------------------------------------------------------------

    dis "Step 1: Pre-QC-assignment code"

    ** Generate household ID (using serial before dropping)
    gegen long hh_id = group(year serial)

    ** Drop unnecessary variables
    foreach var in sample cbserial {
        capture drop `var'
    }

    ** Define basic age flags
    gen byte child = (age <= 17)
    gen byte adult = (age >= 18)
    gen byte elder = (age >= 65)

    ** Tax unit ID (smaller of two person locations in HH)
    gen unit_id = pernum
    replace unit_id = sploc if marst == 1 & sploc != 0 & pernum > sploc
    label var unit_id "Unique ID for tax units"

    ** Count of individuals per married couple
    bysort hh_id unit_id: gen byte unit_ct = _N

    ** QC eligibility tests
    gen byte age_test = (age < 19) | ((age < 24) & (school == 2))
    gen byte citizen_test = (citizen != 3)
    gen byte joint_test = !inlist(marst, 1, 2, 3)

    ** Define potential qualifying children
    gen byte qc = (age_test == 1) & (citizen_test == 1) & (joint_test == 1)
    label var qc "Potential qualifying child"

    ** Relationship flags
    gen byte hoh = (related == 101)
    gen byte sibling = (related == 701)
    gen byte foster = (related == 1242)
    gen byte grandchild = (related == 901)

    ** -------------------------------------------------------------------------
    ** Step 2: Run QC assignment program
    ** -------------------------------------------------------------------------

    dis "Step 2: Run QC-assignment code"
	
	** Drop if missing pernum 
	drop if missing(pernum)
	
    ** Run QC assignment program
    qc_assignment

    ** -------------------------------------------------------------------------
    ** Step 3: Create household composition variables
    ** -------------------------------------------------------------------------

    dis "Step 3: Create household composition variables"

    ** Cap QC count at 3
    replace qc_ct = 3 if qc_ct > 3
    label var qc_ct "Count of qualifying children (QC)"
    label define lb_qc_ct 0 "0" 1 "1" 2 "2" 3 "3+"
    label values qc_ct lb_qc_ct

    ** Number of own children (capped at 3)
    gen kid_ct = nchild
    replace kid_ct = 3 if nchild > 3
    label var kid_ct "Count of children (Any)"
    label values kid_ct lb_qc_ct

    ** Presence indicators
    gen byte qc_present = (qc_ct > 0)
    label var qc_present "1+ qualifying children present"
    label define lb_qc_present 0 "No qualifying children" 1 "1+ qualifying children"
    label values qc_present lb_qc_present

    gen byte kid_present = (nchild > 0)
    label var kid_present "1+ own children present"

    ** Parent presence indicators
    gen byte mom_present = (momloc != 0)
    gen byte dad_present = (poploc != 0)
    gen byte mom2_present = (momloc2 != 0)
    gen byte dad2_present = (poploc2 != 0)
    egen int parent_ct = rowtotal(mom_present dad_present mom2_present dad2_present)
    drop momloc* poploc* mom*_present dad*_present

    ** Compressed brackets of minimum age among QC
    gen minage_qc_compr = 0
    replace minage_qc_compr = 1 if inrange(min_qc_age, 1, 5)
    replace minage_qc_compr = 2 if inrange(min_qc_age, 6, 12)
    replace minage_qc_compr = 3 if inrange(min_qc_age, 13, 23)
    label var minage_qc_compr "Minimum age among QC (compressed)"
    label define lb_minage_c 0 "No QC" 1 "0-5" 2 "6-12" 3 "13-23"
    label values minage_qc_compr lb_minage_c

    ** Detailed brackets of minimum age among QC
    gen minage_qc = 0
    replace minage_qc = 1 if inrange(min_qc_age, 0, 1)
    replace minage_qc = 2 if inrange(min_qc_age, 2, 3)
    replace minage_qc = 3 if inrange(min_qc_age, 4, 6)
    replace minage_qc = 4 if inrange(min_qc_age, 7, 9)
    replace minage_qc = 5 if inrange(min_qc_age, 10, 13)
    replace minage_qc = 6 if inrange(min_qc_age, 14, 17)
    replace minage_qc = 7 if inrange(min_qc_age, 18, 24)
    label var minage_qc "Minimum age among QC"
    label define lb_minage_qc 0 "No QC" 1 "0-1" 2 "2-3" 3 "4-6" ///
                              4 "7-9" 5 "10-13" 6 "14-17" 7 "18-23"
    label values minage_qc lb_minage_qc

    ** Minimum age among own children
    gen minage_kid = 0
    replace minage_kid = 1 if inrange(yngch, 0, 1) & kid_present == 1
    replace minage_kid = 2 if inrange(yngch, 2, 3) & kid_present == 1
    replace minage_kid = 3 if inrange(yngch, 4, 6) & kid_present == 1
    replace minage_kid = 4 if inrange(yngch, 7, 9) & kid_present == 1
    replace minage_kid = 5 if inrange(yngch, 10, 13) & kid_present == 1
    replace minage_kid = 6 if inrange(yngch, 14, 17) & kid_present == 1
    replace minage_kid = 7 if inrange(yngch, 18, 24) & kid_present == 1
    label var minage_kid "Minimum age among own children"
    label values minage_kid lb_minage_qc

    drop yngch nchild

    ** Household-level counts
    gen byte tmp_child = (age < 18)
    gen byte tmp_adult = (age >= 18) & (qc == 0)

    bysort hh_id: gen hh_person_ct = _N
    bysort hh_id: egen hh_child_ct = total(tmp_child)
    bysort hh_id: egen hh_qc_ct = total(qc)
    bysort hh_id: egen hh_adult_ct = total(tmp_adult)

    gen hh_child_present = (hh_child_ct > 0)
    gen hh_qc_present = (hh_qc_ct > 0)

    label var hh_person_ct "Count of individuals in household"
    label var hh_child_ct "Count of children in household"
    label var hh_qc_ct "Count of QC in household"
    label var hh_adult_ct "Count of adults in household"

    drop tmp_child tmp_adult

    ** SAMPLE RESTRICTION: Drop if under 18
    drop if age < 18

    ** -------------------------------------------------------------------------
    ** Step 4: Demographic variables
    ** -------------------------------------------------------------------------

    dis "Step 4: Assign demographic variables"

    ** Age sample indicators
    gen byte age_sample_20_50 = inrange(age, 20, 50)
    gen byte age_sample_20_49 = inrange(age, 20, 49)
    gen byte age_sample_25_54 = inrange(age, 25, 54)

    ** Educational attainment
    gen education = .
    replace education = 1 if educd <= 61           // No HS degree
    replace education = 2 if inrange(educd, 62, 64) // HS grad
    replace education = 3 if inrange(educd, 65, 80) // Some college
    replace education = 4 if educd > 80             // College grad
    label var education "Educational attainment"
    label define lb_education 1 "No High School" 2 "High School" ///
                              3 "Some college" 4 "College degree"
    label values education lb_education

    ** Currently in school
    gen byte in_school = (school == 2)
    label var in_school "Currently in school"

    ** 5-year age brackets
    gegen age_bracket = cut(age), at(20(5)56)
    replace age_bracket = 50 if age >= 50 & age <= 55
    label define lb_age_bracket 20 "20-24" 25 "25-29" 30 "30-34" ///
                                35 "35-39" 40 "40-44" 45 "45-49" 50 "50-55"
    label values age_bracket lb_age_bracket
    label var age_bracket "Age brackets"

    ** 10-year age brackets
    gen age_grps = 0
    replace age_grps = 1 if inrange(age, 20, 29)
    replace age_grps = 2 if inrange(age, 30, 39)
    replace age_grps = 3 if inrange(age, 40, 50)
    label define lb_age_grps 1 "20-29" 2 "30-39" 3 "40-50"
    label values age_grps lb_age_grps

    ** Marital status
    gen byte married = inlist(marst, 1, 2)
    label var married "Married"
    label define lb_married 0 "Single" 1 "Married"
    label values married lb_married
	
	** Marital status
    gen byte mfs = inlist(marst, 3) & sploc == 0
    label var mfs "MFS (Seperated)"
    label define lb_mfs 0 "Single / Married" 1 "MFS"
    label values mfs lb_mfs

    ** Hispanic origin
    gen byte hispanic = (hispan != 0)
    label var hispanic "Hispanic"

    ** Race categories
    gen race_group = 4                              // Other
    replace race_group = 1 if race == 1             // White
    replace race_group = 2 if race == 2             // Black
    replace race_group = 3 if inlist(race, 4, 5, 6) // Asian
    label var race_group "Race"
    label define lb_race 1 "White" 2 "Black" 3 "Asian" 4 "Other"
    label values race_group lb_race

    ** Race x Hispanic categories
    gen race_hisp = 4                                // Other
    replace race_hisp = 1 if hispan != 0             // Hispanic
    replace race_hisp = 2 if hispan == 0 & race == 1 // Non-Hispanic White
    replace race_hisp = 3 if hispan == 0 & race == 2 // Non-Hispanic Black
    label var race_hisp "Race and Hispanic origin"
    label define lb_race_hisp 1 "Hispanic" 2 "Non-Hispanic White" ///
                              3 "Non-Hispanic Black" 4 "Other"
    label values race_hisp lb_race_hisp

    ** Female indicator
    gen byte female = (sex == 2)
    label var female "Female"

    ** Drop raw demographic variables
    drop hispan race sex educ educd relate related school marst

    ** -------------------------------------------------------------------------
    ** Step 5: Employment variables
    ** -------------------------------------------------------------------------

    dis "Step 5: Assign employment variables"

    ** Employed last year
    gen byte employed_y = (workedyr == 3)
    gen byte employed_y_reported = (qworkedy == 0)
    label var employed_y "Employed last year"

    ** Employed last week
    gen byte employed_w = (empstat == 1)
    gen byte employed_w_reported = (qempstat == 0)
    label var employed_w "Employed last week"

    ** In labor force last week
    gen byte labor_force_w = inlist(empstat, 1, 2)
    label var labor_force_w "In labor force last week"

    ** Hours worked last year
    gen hours_worked_y = .
    replace hours_worked_y = uhrswork if employed_y == 1 & ///
        !missing(uhrswork) & uhrswork > 0 & uhrswork < 99
    gen byte hours_worked_y_reported = (quhrswor == 0)
    label var hours_worked_y "Usual hours worked per week"

    ** Weeks worked last year (bin mid-points)
    gen weeks_worked_y = 0
    replace weeks_worked_y = 7 if wkswork2 == 1
    replace weeks_worked_y = 20 if wkswork2 == 2
    replace weeks_worked_y = 33 if wkswork2 == 3
    replace weeks_worked_y = 44 if wkswork2 == 4
    replace weeks_worked_y = 48.5 if wkswork2 == 5
    replace weeks_worked_y = 51 if wkswork2 == 6
    gen byte weeks_worked_y_reported = (qwkswork2 == 0)
    label var weeks_worked_y "Weeks worked last year"

    ** Part-time and full-time employment
    gen byte part_time_y = (employed_y == 1) & !missing(hours_worked_y) & (hours_worked_y < 35)
    gen byte full_time_y = (employed_y == 1) & !part_time_y
    label var part_time_y "Employed part-time last year"
    label var full_time_y "Employed full-time last year"

    ** Self-employment
    gen byte self_employed_w = (classwkr == 1)
    label var self_employed_w "Self-employed last week"

    gen se_income_y = 0
    replace se_income_y = incbus00 if !missing(incbus00) & incbus00 != 999999
    gen byte self_employed_y = (se_income_y != 0)
    gen byte self_employed_pos_y = (se_income_y > 0)
    label var self_employed_y "Self-employment income last year"

    ** Armed services
    gen byte armed_services = inlist(empstatd, 14, 15)
    label var armed_services "In armed services"

    ** Clean up employment variables
    drop workedyr empstat classwkr uhrswork labforce ///
         quhrswor qwkswork2 qempstat qworkedy

    ** -------------------------------------------------------------------------
    ** Step 6: Earnings variables
    ** -------------------------------------------------------------------------

    dis "Step 6: Assign earnings variables"

    ** Total income (real and nominal)
    gen inctot_real = inctot * cpi99 / 0.652
    gen inctot_nom = inctot
    label var inctot_real "Total income (2019 USD)"
    label var inctot_nom "Total income (Nominal)"

    ** Earned income
    gen incearn_real = incearn * cpi99 / 0.652
    gen incearn_nom = incearn
    gen byte incearn_reported = (qincwage == 0 & qincbus == 0)
    label var incearn_real "Earned income (2019 USD)"
    label var incearn_nom "Earned income (Nominal)"

    ** Wage income
    gen incwage_real = incwage * cpi99 / 0.652
    gen incwage_nom = incwage
    gen byte incwage_reported = (qincwage == 0)
    label var incwage_real "Wage income (2019 USD)"

	** SE income
	gen incse_nom = incearn - incwage 
    gen incse_real = incse_nom * cpi99 / 0.652
    gen byte incse_reported = (qincwage == 0 & qincbus == 0)
    label var incse_nom "SE income (Nominal)"
	label var incse_real "SE income (2019 USD)"
	
	** Investment income
	gen incinvst_nom = incinvst
    gen incinvst_real = incinvst_nom * cpi99 / 0.652
    gen byte incinvst_reported = (qincinvs == 0 )
    label var incinvst_nom "Investment income (Nominal)"
	label var incinvst_real "Investment income (2019 USD)"
	
    ** Welfare income
    gen incwel_real = 0
    replace incwel_real = incwelfr * cpi99 / 0.652 if ///
        !missing(incwelfr) & incwelfr != 999999
    gen incwel_nom = 0
    replace incwel_nom = incwelfr if !missing(incwelfr) & incwelfr != 999999
    label var incwel_real "Welfare income (2019 USD)"

	** Loop over income variables 
	foreach v1 in "inctot" "incwage" "incearn" "incse" "incinvst" {
		
		** Loop over real vs nominal 
		foreach v2 in "real" "nom" {
			
			** Household-level income sums
			bysort hh_id: egen `v1'_hh_`v2' = total(`v1'_`v2') 

			** Tax-unit level income sums
			bysort hh_id unit_id: egen `v1'_tax_`v2' = total(`v1'_`v2') 
			
			
		} // END V2 LOOP 
		
	} // END V1 LOOP
 	
    ** Drop raw income variables
    drop inctot incearn incwage incwelfr incbus00 incinvst incsupp incother ///
         qincwage qincbus qincwelf

    ** -------------------------------------------------------------------------
    ** Step 7: Merge with unemployment and minimum wage data
    ** -------------------------------------------------------------------------

    dis "Step 7: Merge with unemployment and minimum wage data"

    ** Generate merge keys
    gen state_fips = statefip
    gen county_fips = countyfip

    ** Merge state unemployment
    merge m:1 state_fips year using "${data}interim/st_unemp_year.dta", ///
        gen(m_state_unemp)
    tab statefip m_state_unemp, m
    drop if m_state_unemp == 2
    drop m_state_unemp

    ** Merge state minimum wage
    merge m:1 state_fips year using "${data}interim/st_minwage_year.dta", ///
        gen(m_state_mw)
    tab statefip m_state_mw, m
    drop if m_state_mw == 2
    drop m_state_mw

    ** Merge county unemployment
    merge m:1 state_fips county_fips year using "${data}interim/ct_unemp_year.dta", ///
        gen(m_county_unemp)
    tab statefip m_county_unemp, m

    ** For unmatched counties, use average of unmatched counties in that state
    gen ui_tmp1 = county_unemp if m_county_unemp == 2
    bysort state_fips year: egen ui_tmp2 = mean(ui_tmp1)
    replace county_unemp = ui_tmp2 if county_fips == 0 | m_county_unemp == 1
    drop if m_county_unemp == 2
    drop ui_tmp1 ui_tmp2 m_county_unemp

    ** Clean up
    drop statefip countyfip

    ** Label unemployment variables
    label var state_unemp "State unemployment rate"
    label var county_unemp "County unemployment rate"
    label var mean_st_mw "Binding state minimum wage"

    ** -------------------------------------------------------------------------
    ** Step 8: State treatment assignment
    ** -------------------------------------------------------------------------

    dis "Step 8: State treatment assignment"

    ** Initialize variable (default: control states with no EITC change)
    gen state_status = 1

    ** Treated state: California
    replace state_status = 2 if state_fips == 6

    ** States with EITC changes (excluded)
    local eitc_change_states "8 9 15 17 19 20 22 23 24 25 26 27 30 34 35 39 41 44 45 50 55"
    foreach s of local eitc_change_states {
        replace state_status = 0 if state_fips == `s'
    }

    ** Excluded states (Alaska and DC)
    replace state_status = -1 if inlist(state_fips, 2, 11)

    label var state_status "State treatment status"
    label define lb_state_status -1 "Excluded" 0 "EITC change" 1 "Control" 2 "California"
    label values state_status lb_state_status

    ** SAMPLE RESTRICTION: Drop if assigned as QC
    drop if qc == 1

    ** -------------------------------------------------------------------------
    ** Step 9: TAXSIM Calculations (Simulation 1 and 3)
    ** -------------------------------------------------------------------------

    ** Only run TAXSIM for years 2010-2019
    if inrange(`y', 2010, 2019) {

        dis "Step 9: TAXSIM Calculations for year `y'"

        ** ---------------------------------------------------------------------
        ** Step 9a: Create FIPS to SOI Crosswalk
        ** ---------------------------------------------------------------------

        ** FIPS codes map to SOI codes (note: FIPS 3,7,14,43,52 don't exist)
        recode state_fips ///
            (1=1) (2=2) (4=3) (5=4) (6=5) (8=6) (9=7) (10=8) (11=9) ///
            (12=10) (13=11) (15=12) (16=13) (17=14) (18=15) (19=16) (20=17) (21=18) ///
            (22=19) (23=20) (24=21) (25=22) (26=23) (27=24) (28=25) (29=26) (30=27) ///
            (31=28) (32=29) (33=30) (34=31) (35=32) (36=33) (37=34) (38=35) (39=36) ///
            (40=37) (41=38) (42=39) (44=40) (45=41) (46=42) (47=43) (48=44) (49=45) ///
            (50=46) (51=47) (53=48) (54=49) (55=50) (56=51), gen(state_soi)
        label var state_soi "State SOI code (for TAXSIM)"

        ** ---------------------------------------------------------------------
        ** Step 9b: Prepare TAXSIM Input Variables
        ** ---------------------------------------------------------------------

        ** Create unique tax unit ID
        sort hh_id unit_id pernum
        gegen double taxsimid = group(hh_id unit_id)
        label var taxsimid "TAXSIM tax unit ID"

        ** Create TAXSIM input file
        gen state = state_soi

        ** Marital status for TAXSIM (1=single, 2=married joint, 6=married separate)
        gen byte mstat = 1
        replace mstat = 2 if married == 1
        replace mstat = 6 if mfs == 1
        label var mstat "TAXSIM marital status"

        ** Dependent exemptions (capped at 3 already)
        gen byte depx = qc_ct
        label var depx "TAXSIM dependent exemptions"

        ** Primary taxpayer age
        gen page = age
        label var page "TAXSIM primary taxpayer age"

        ** Spouse age (for married couples, use other spouse's age)
        gen sage = 0
        bysort hh_id unit_id (pernum): gen tmp_max_age = age[_N]
        bysort hh_id unit_id (pernum): gen tmp_min_age = age[1]
        replace sage = tmp_max_age if age == tmp_min_age & married == 1 & unit_ct > 1
        replace sage = tmp_min_age if age == tmp_max_age & married == 1 & unit_ct > 1
        drop tmp_max_age tmp_min_age
        label var sage "TAXSIM spouse age"

        ** Primary wages (own wage income, non-negative)
        gen double pwages = max(incwage_nom, 0)
        label var pwages "TAXSIM primary wages"

        ** Spousal wages (tax unit wages minus own wages, non-negative)
        gen double swages = max(incwage_tax_nom - incwage_nom, 0)
        label var swages "TAXSIM spouse wages"

        ** Primary self-employment income (can be negative)
        gen double psemp = incse_nom
        label var psemp "TAXSIM primary self-employment"

        ** Spousal self-employment income
        gen double ssemp = incse_tax_nom - incse_nom
        label var ssemp "TAXSIM spouse self-employment"

        ** Interest/dividend income (investment income, non-negative)
        gen double intrec = max(incinvst_tax_nom, 0)
        label var intrec "TAXSIM interest/dividend income"

        ** Other property income calculation
        ** Start with total tax-unit income, subtract enumerated taxable income and non-taxable transfers
        gen double otherprop = inctot_tax_nom
        replace otherprop = otherprop - max(incwage_tax_nom, 0)  // wages
        replace otherprop = otherprop - incse_tax_nom            // SE income
        replace otherprop = otherprop - incinvst_tax_nom         // investment
        replace otherprop = otherprop - incwel_nom               // welfare (non-taxable)
        replace otherprop = max(otherprop, 0)                    // floor at zero
        label var otherprop "TAXSIM other property income"

        ** Flag for primary filer in tax unit (one observation per tax unit for TAXSIM)
        gen byte primary_filer = (unit_id == pernum)
        label var primary_filer "Primary filer in tax unit"

        ** ---------------------------------------------------------------------
        ** Simulation 1 - Observed Characteristics (CA Only)
        ** ---------------------------------------------------------------------

        ** Initialize output variables
        gen double taxsim_sim1_fedeitc = .
        gen double taxsim_sim1_steitc = .
        label var taxsim_sim1_fedeitc "Federal EITC (Sim 1: observed)"
        label var taxsim_sim1_steitc "State EITC (Sim 1: observed)"

        ** Preserve current data
        preserve

        ** Keep CA residents only, one observation per tax unit
        keep if primary_filer == 1

        ** Keep required TAXSIM variables
        keep taxsimid year state mstat depx page sage pwages swages psemp ssemp intrec otherprop

        ** Order variables for TAXSIM
        order taxsimid year state mstat depx page sage pwages swages psemp ssemp intrec otherprop

        ** Run TAXSIM
        cd "${data}taxsim"

        ** Export and run TAXSIM
        capture noisily taxsimlocal35, full
        if _rc != 0 {
            di as error "TAXSIM Simulation 1 failed for year `y'"
            cd "${dir}"
            restore
        }
        else {
            ** Load results
            clear
            import delimited results.raw, clear

            ** Return to main directory
            cd "${dir}"

            ** Clean results
            destring taxsimid, replace force
            drop if missing(taxsimid)

            ** Keep EITC variables
            keep taxsimid year v25 v39
            rename v25 sim1_fedeitc
            rename v39 sim1_steitc

            ** Save temporary file
            tempfile sim1_results
            save `sim1_results'

            ** Restore and merge
            restore

            ** Merge results back
            merge m:1 taxsimid year using `sim1_results', nogen keep(master match)

            ** Update main variables
            replace taxsim_sim1_fedeitc = sim1_fedeitc if !missing(sim1_fedeitc)
            replace taxsim_sim1_steitc = sim1_steitc if !missing(sim1_steitc)
            drop sim1_fedeitc sim1_steitc

            ** Verification
            dis "Simulation 1 verification for year `y':"
            tab year if state_fips == 6, sum(taxsim_sim1_steitc)
        }

        ** ---------------------------------------------------------------------
        ** Simulation 3 - ATR at CalEITC Kink (Sex-Specific)
        ** ---------------------------------------------------------------------

        ** Initialize output variable
        gen double taxsim_sim3_atr_st = .
        label var taxsim_sim3_atr_st "Average Tax Rate at CalEITC kink (via TAXSIM)"

        ** Load CalEITC parameters
        preserve

        import delimited "${data}eitc_parameters/caleitc_params.txt", clear

        ** Handle missing values - pwages is for years >= 2015, pwages_unadj for < 2015
        destring pwages pwages_unadj, replace force

        ** Rename
        rename tax_year year
        rename qc_ct depx

        ** Save parameters
        tempfile caleitc_params
        save `caleitc_params'

        restore

        ** Preserve current data
        preserve

        ** Keep one observation per tax unit
        keep if primary_filer == 1

        ** Keep required variables
        keep taxsimid state mstat year page sage depx intrec otherprop cpi99

        ** Merge CalEITC parameters
        merge m:1 year depx using `caleitc_params', keep(master match) nogen

        ** Set wages to CalEITC-maximizing income
        ** For years >= 2015: use pwages column
        ** For years < 2015: use pwages_unadj with CPI adjustment
        replace pwages = pwages_unadj * (${cpi_2015} / cpi99) if year < 2015 & !missing(pwages_unadj)

        ** Other income variables
        gen swages = 0  // Set to zero for kink calculation
        gen psemp = 0
        gen ssemp = 0

        ** Save cell info
        tempfile sim3_pretaxsim
        save `sim3_pretaxsim'

        ** Keep TAXSIM input
        keep taxsimid year state mstat depx page sage pwages swages psemp ssemp intrec otherprop
        order taxsimid year state mstat depx page sage pwages swages psemp ssemp intrec otherprop

        ** Run TAXSIM at CalEITC kink
        cd "${data}taxsim"

        capture noisily taxsimlocal35, full
        if _rc != 0 {
            di as error "TAXSIM Simulation 3 (run 1) failed for year `y'"
            cd "${dir}"
            restore
        }
        else {
            ** Load results
            clear
            import delimited results.raw, clear
            cd "${dir}"

            ** Clean results
            destring taxsimid, replace force
            drop if missing(taxsimid)

            ** Keep tax variables (v4=fiitax, v5=siitax, v7=fica, v10=AGI)
            keep taxsimid fiitax siitax fica v10
            rename v10 agi

            tempfile sim3_run1
            save `sim3_run1'

            ** Now run with pwages = 0
            use `sim3_pretaxsim', clear
            replace pwages = 0

            keep taxsimid year state mstat depx page sage pwages swages psemp ssemp intrec otherprop
            order taxsimid year state mstat depx page sage pwages swages psemp ssemp intrec otherprop

            cd "${data}taxsim"
            capture noisily taxsimlocal35, full

            if _rc != 0 {
                di as error "TAXSIM Simulation 3 (run 2) failed for year `y'"
                cd "${dir}"
                restore
            }
            else {
                ** Load results
                clear
                import delimited results.raw, clear
                cd "${dir}"

                ** Clean results
                destring taxsimid, replace force
                drop if missing(taxsimid)

                ** Keep tax variables (v4=fiitax, v5=siitax, v7=fica, v10=AGI)
                keep taxsimid fiitax siitax fica v10
                rename v10 agi_0
                rename fiitax fiitax_0
                rename siitax siitax_0
                rename fica fica_0

                ** Save data
                tempfile sim3_run2
                save `sim3_run2'

                ** Restore data
                restore

                ** Merge with run 1 and 2 results
                merge m:1 taxsimid using `sim3_run1', nogen keep(master match)
                merge m:1 taxsimid using `sim3_run2', nogen keep(master match)

                ** Calculate ATR (Kleven 2023, Eq. 7)
                ** ATR = ((fiitax - fiitax_0) + (siitax - siitax_0) + fica) / agi
                gen double atr_st = .
                replace atr_st = ((fiitax - fiitax_0) + (siitax - siitax_0) + fica) / agi ///
                    if agi > 0 & !missing(agi)

                ** Update main variable
                replace taxsim_sim3_atr_st = atr_st if !missing(atr_st)

                label var taxsim_sim3_atr_st "Average Tax Rate at CalEITC Max Inc, via TAXSIM"

                ** Verification
                dis "Simulation 3 verification for year `y':"
                tab year qc_ct, sum(taxsim_sim3_atr_st)

                ** Clean up sim3 temp variables
                capture drop fiitax siitax fica agi fiitax_0 siitax_0 fica_0 agi_0 atr_st
            }
        }

        ** Clean up temporary TAXSIM variables (keep state_soi and mstat for sim2)
        capture drop depx page sage pwages swages psemp ssemp intrec otherprop primary_filer taxsimid state

    } // END IF YEAR IN 2010-2019

    ** -------------------------------------------------------------------------
    ** Save processed file for year
    ** -------------------------------------------------------------------------

    dis "Year `y' done. Saving."

    ** Rename weight variable for consistency
    rename perwt weight

    ** Compress
    compress

    ** Save
    save "${data}final/acs_`y'_clean.dta", replace

    clear

}


** =============================================================================
** (4) APPEND ALL YEARS INTO SINGLE FILE
** =============================================================================

dis ""
dis "=============================================="
dis "Appending all years into single file"
dis "=============================================="

** Loop to append
forvalues y = $start_year_data(1)$end_year_data {
    capture confirm file "${data}final/acs_`y'_clean.dta"
    if _rc == 0 {
        append using "${data}final/acs_`y'_clean.dta"
    }
}

** Save combined file
save "${data}final/acs_working_file.dta", replace

** =============================================================================
** (5) TAXSIM Calculations - Simulation 2 Only
** =============================================================================
** Note: Simulations 1 and 3 are now computed within the year loop above

dis ""
dis "=============================================="
dis "Running Simulation 2 (cell-based instrument)"
dis "=============================================="

** -------------------------------------------------------------------------
** Prepare TAXSIM Input Variables for Simulation 2
** -------------------------------------------------------------------------

** Create unique tax unit ID for the combined file
sort hh_id unit_id pernum
gegen double taxsimid = group(hh_id unit_id)
label var taxsimid "TAXSIM tax unit ID"

** Create TAXSIM state variable (state_soi already exists from year loop for 2010-2019)
** For years outside 2010-2019, create state_soi if needed
capture confirm variable state_soi
if _rc != 0 {
    recode state_fips ///
        (1=1) (2=2) (4=3) (5=4) (6=5) (8=6) (9=7) (10=8) (11=9) ///
        (12=10) (13=11) (15=12) (16=13) (17=14) (18=15) (19=16) (20=17) (21=18) ///
        (22=19) (23=20) (24=21) (25=22) (26=23) (27=24) (28=25) (29=26) (30=27) ///
        (31=28) (32=29) (33=30) (34=31) (35=32) (36=33) (37=34) (38=35) (39=36) ///
        (40=37) (41=38) (42=39) (44=40) (45=41) (46=42) (47=43) (48=44) (49=45) ///
        (50=46) (51=47) (53=48) (54=49) (55=50) (56=51), gen(state_soi)
    label var state_soi "State SOI code (for TAXSIM)"
}

gen state = state_soi

** Marital status for TAXSIM (mstat already exists from year loop for 2010-2019)
capture confirm variable mstat
if _rc != 0 {
    gen byte mstat = 1
    replace mstat = 2 if married == 1
    replace mstat = 6 if mfs == 1
    label var mstat "TAXSIM marital status"
}

** Dependent exemptions
gen byte depx = qc_ct
label var depx "TAXSIM dependent exemptions"

** Primary taxpayer age
gen page = age
label var page "TAXSIM primary taxpayer age"

** Spouse age
gen sage = 0
bysort hh_id unit_id (pernum): gen tmp_max_age = age[_N]
bysort hh_id unit_id (pernum): gen tmp_min_age = age[1]
replace sage = tmp_max_age if age == tmp_min_age & married == 1 & unit_ct > 1
replace sage = tmp_min_age if age == tmp_max_age & married == 1 & unit_ct > 1
drop tmp_max_age tmp_min_age
label var sage "TAXSIM spouse age"

** Primary wages
gen double pwages = max(incwage_nom, 0)
label var pwages "TAXSIM primary wages"

** Spousal wages
gen double swages = max(incwage_tax_nom - incwage_nom, 0)
label var swages "TAXSIM spouse wages"

** Primary self-employment income
gen double psemp = incse_nom
label var psemp "TAXSIM primary self-employment"

** Spousal self-employment income
gen double ssemp = incse_tax_nom - incse_nom
label var ssemp "TAXSIM spouse self-employment"

** Interest/dividend income
gen double intrec = max(incinvst_tax_nom, 0)
label var intrec "TAXSIM interest/dividend income"

** Other property income
gen double otherprop = inctot_tax_nom
replace otherprop = otherprop - max(incwage_tax_nom, 0)
replace otherprop = otherprop - incse_tax_nom
replace otherprop = otherprop - incinvst_tax_nom
replace otherprop = otherprop - incwel_nom
replace otherprop = max(otherprop, 0)
label var otherprop "TAXSIM other property income"

** Primary filer flag
gen byte primary_filer = (unit_id == pernum)
label var primary_filer "Primary filer in tax unit"

** -------------------------------------------------------------------------
** Simulation 2 - Simulated Instrument (Sex-Specific Cells)
** -------------------------------------------------------------------------

** Initialize output variables
gen double taxsim_sim2_fedeitc = .
gen double taxsim_sim2_steitc = .
gen double taxsim_sim2_wt = .
label var taxsim_sim2_fedeitc "Federal EITC (Sim 2: simulated)"
label var taxsim_sim2_steitc "State EITC (Sim 2: simulated)"
label var taxsim_sim2_wt "Cell weight (Sim 2)"

** Store CPI values
forvalues y = 2010(1)2019 {
    qui summ cpi99 if year == `y', meanonly
    local cpi_`y' = r(mean)
}

** Preserve current data
preserve

** Create simulated CalEITC instrument using 2014 data
keep if year == 2014

** Keep primary filers only
keep if primary_filer == 1

** Keep required TAXSIM variables
keep taxsimid state mstat depx page sage pwages swages psemp ssemp intrec otherprop ///
    cpi99 education age_bracket female weight

** Order variables
order taxsimid state mstat depx page sage pwages swages psemp ssemp intrec otherprop ///
    cpi99 education age_bracket female weight

** Gen value to help with appending
gen append = 0

** Gen empty year variable
gen year = .

** Save as temporary file
tempfile sim_caleitc_append
save `sim_caleitc_append'
clear

** Loop over years
forvalues y = 2010/2019 {

    ** Append values
    append using `sim_caleitc_append'

    ** Adjust values for inflation
    foreach var of varlist pwages swages psemp ssemp intrec otherprop {
        replace `var' = `var' * (`cpi_`y'' / cpi99) if append == 0
    }

    ** Update year
    replace year = `y' if append == 0

    ** Adjust append helper
    replace append = 1
}

** Generate new taxsim id
rename taxsimid taxsimid_old
gsort year taxsimid_old
gen double taxsimid = _n
drop taxsimid_old

** Save as temporary file
tempfile pretaxsim_sim2
save `pretaxsim_sim2'

** Keep TAXSIM input variables
keep taxsimid year state mstat depx page sage pwages swages psemp ssemp intrec otherprop
order taxsimid year state mstat depx page sage pwages swages psemp ssemp intrec otherprop

** Run TAXSIM
cd "${data}taxsim"

capture noisily taxsimlocal35, full
if _rc != 0 {
    di as error "TAXSIM Simulation 2 failed"
    cd "${dir}"
    restore
}
else {
    ** Load results
    clear
    import delimited results.raw, clear

    ** Return to main directory
    cd "${dir}"

    ** Clean results
    destring taxsimid, replace force
    drop if missing(taxsimid)

    ** Keep EITC variables
    keep taxsimid v25 v39
    rename v25 sim2_fedeitc
    rename v39 sim2_steitc

    ** Merge with cell info
    merge 1:1 taxsimid using `pretaxsim_sim2', nogen

    ** Keep cell identifiers and results
    keep year state depx mstat education age_bracket female ///
         sim2_fedeitc sim2_steitc weight

    ** Collapse to get cell-specific averages
    gen sim2_cellwt = 1
    collapse (sum) sim2_cellwt ///
             (mean) sim2_fedeitc sim2_steitc ///
        [aw = weight], by(year state female depx mstat education age_bracket)

    ** Rename for merge
    rename state state_soi
    rename depx qc_ct

    ** Save for merge back to main data
    tempfile sim2_results
    save `sim2_results'

    ** Restore original data
    restore

    ** Merge simulation 2 results by cell dimensions
    merge m:1 year state_soi female qc_ct mstat education age_bracket ///
        using `sim2_results', nogen keep(master match)

    ** Update main variables
    replace taxsim_sim2_fedeitc = sim2_fedeitc if !missing(sim2_fedeitc)
    replace taxsim_sim2_steitc = sim2_steitc if !missing(sim2_steitc)
    replace taxsim_sim2_wt = sim2_cellwt if !missing(sim2_cellwt)
    capture drop sim2_fedeitc sim2_steitc sim2_cellwt

    ** Verification
    dis "Simulation 2 verification:"
    tab year female, sum(taxsim_sim2_steitc)
}

** Clean up temporary TAXSIM variables
drop depx page sage pwages swages psemp ssemp intrec otherprop primary_filer taxsimid state

** Save combined file
save "${data}final/acs_working_file.dta", replace


** End log
log close log_01
