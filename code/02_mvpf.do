/*******************************************************************************
File Name:      05_mvpf.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Calculates the Marginal Value of Public Funds (MVPF) for the CalEITC

                The MVPF framework calculates:
                - Numerator: Willingness-to-pay (value to recipients)
                - Denominator: Net fiscal cost (direct cost + behavioral externalities)

                Key insight: CalEITC creates two labor supply responses:
                1) Non-work → Part-time (extensive margin): Increases tax revenue
                2) Full-time → Part-time (intensive margin): Decreases tax revenue

                Uses estimated full-time effect to adjudicate between channels.

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_02_mvpf
log using "${logs}02_mvpf_log_${date}", name(log_02_mvpf) replace text

** =============================================================================
** (1) SETUP: Load CalEITC Parameters
** =============================================================================

** Load caleitc_max_inc parameters (income that maximizes CalEITC credit)
import delimited "${data}eitc_parameters/caleitc_params.txt", clear

** Keep required variables
keep tax_year qc_ct pwages pwages_unadj

** Use unadjusted values for pre-2015 years (when pwages is missing)
replace pwages = pwages_unadj if missing(pwages) | pwages == .
drop pwages_unadj

** Rename to match expected variable name
rename pwages pwages_calmax
rename tax_year year

** Save parameter file
save "${data}interim/caleitc_max_inc_max_cred.dta", replace

** =============================================================================
** (2) DEFINE FISCAL COST SIMULATION PROGRAM
** =============================================================================

capture program drop fiscal_cost
program define fiscal_cost

    ** -------------------------------------------------------------------------
    ** Define arguments
    ** -------------------------------------------------------------------------
    args    sample      /// Sample: 0=all, 1=low ed, 2=age 20-49, 3=age 20-64
            ft_pt_cf_inc /// FT-PT counterfactual income: 1=min wage, 2=$27,000
            p_sta       /// Period start year (e.g., 2012)
            p_end       /// Period end year (e.g., 2017)
            spec_d      /// Include demographics in spec (0/1)
            spec_u      /// Include unemployment in spec (0/1)
            spec_m      /// Include minimum wage in spec (0/1)
            contrs      /// Control states: 0=all, 1=no eitc, 2=medicaid, 3=minwage
            hetero      /// Heterogeneity: 0=none, 1=year, 2=qc_ct, 3=hh_adult_ct
            full        /// Adjust for discrete effect: 0=no, 1=yes
            model       // Model count for tracking

    ** -------------------------------------------------------------------------
    ** Load ACS data, restricted to base sample
    ** -------------------------------------------------------------------------

    ** Note: Load with broadest age range (20-64), filter by sample option later
    use if female == 1 & married == 0 & in_school == 0 & ///
         inrange(age, 20, 64) & citizen_test == 1 & ///
         inrange(year, `p_sta', `p_end') ///
        using "${data}final/acs_working_file.dta", clear

    ** -------------------------------------------------------------------------
    ** Set sample based on argument
    ** -------------------------------------------------------------------------

    if `sample' == 0 {
        dis "Sample: All, 20-49"
        gen sample = inrange(age, 20, 49)
    }
    else if `sample' == 1 {
        dis "Sample: Low-ed, 20-49"
        gen sample = (education < 4) & inrange(age, 20, 49)
    }
    else if `sample' == 2 {
        dis "Sample: All, 20-49"
		gen sample = inrange(age, 20, 64)    
	}
    else if `sample' == 3 {
        dis "Sample: Low-ed, 20-64"
        gen sample = (education < 4) & inrange(age, 20, 64)
    }

    ** -------------------------------------------------------------------------
    ** Set control states based on argument
    ** -------------------------------------------------------------------------

    if `contrs' == 0 {
        dis "Control states: All states without EITC changes"
        keep if state_status > 0
    }
    else if `contrs' == 1 {
        dis "Control states: Only states without any state EITCs"
        keep if state_status > 0
        keep if !inlist(state_fips, 2, 8, 9, 10, 11, 15, ///
                                    17, 18, 19, 23, 24, 25, ///
                                    26, 27, 30, 31, 34, 35, ///
                                    39, 40, 41, 44, 45, 49, ///
                                    50, 51, 55)
    }
    else if `contrs' == 2 {
        dis "Control states: Only Medicaid expansion states (2014)"
        keep if state_status > 0
        keep if inlist(state_fips, 4, 5, 6, 8, 9, 10, 11, ///
                                   15, 17, 19, 21, 24, ///
                                   25, 26, 27, 32, 33, 34, ///
                                   35, 36, 38, 39, 41, 44, ///
                                   50, 53, 54)
    }
    else if `contrs' == 3 {
        dis "Control states: Only states with minimum wage increases in 2014"
        keep if inlist(state_fips, 6, 9, 10, 26, 27, 34)
    }

    ** -------------------------------------------------------------------------
    ** Create main DID variables
    ** -------------------------------------------------------------------------

    gen ca = (state_fips == 6)
    gen childXyearXca = cond(qc_present == 1 & ca == 1, year, 2014)
    gen treated = (state_fips == 6 & qc_present == 1 & year >= 2015)
    label var treated "Treated"

	replace hh_adult_ct = 3 if hh_adult_ct > 3 
	
    ** -------------------------------------------------------------------------
    ** Set specifications for regressions
    ** -------------------------------------------------------------------------

    ** Base fixed effects (triple-diff)
    local did "qc_ct year state_fips"
    local did "`did' state_fips#year"
    local did "`did' state_fips#qc_ct"
    local did "`did' year#qc_ct"

    local controls ""
    local unemp ""

    ** Add demographic controls if specified
    if `spec_d' == 1 {
        dis "Including demographic controls"
        local controls "i.education i.age_bracket i.minage_qc"
        local controls "`controls' i.race_group i.hispanic i.hh_adult_ct"
    }

    ** Add unemployment controls if specified
    if `spec_u' == 1 {
        dis "Including unemployment controls"
        local unemp "`unemp' c.state_unemp#i.qc_ct"
    }

    ** Add minimum wage controls if specified
    if `spec_m' == 1 {
        dis "Including minimum wage controls"
        local unemp "`unemp' c.mean_st_mw#i.qc_ct"
    }

    ** -------------------------------------------------------------------------
    ** Set treatment heterogeneity
    ** -------------------------------------------------------------------------

    if `hetero' == 0 {
        dis "No treatment heterogeneity"
        local treated "treated"
        gen placeholder = 1
        local het_vars "placeholder"
    }

    if `hetero' == 1 {
        dis "Treatment varies by year"
        local treated "i1.treated#i(2015/`p_end').year"
        local het_vars "year"
    }

    if `hetero' == 2 {
        dis "Treatment varies by count of qualifying children"
        local treated "i1.treated#i(1/3).qc_ct"
        local het_vars "qc_ct"
    }

    if `hetero' == 3 {
        dis "Treatment varies by count of adults in HH"
        local treated "i1.treated#i(1/3).hh_adult_ct"
        local het_vars "hh_adult_ct"
    }

    ** -------------------------------------------------------------------------
    ** Run regressions for full-time and part-time effects
    ** -------------------------------------------------------------------------

    foreach var of varlist full_time_y part_time_y {

        if "`var'" == "full_time_y" local txt "full-time"
        if "`var'" == "part_time_y" local txt "part-time"

        ** For "full" option, restrict FT effect to discrete location ($24K-$30K)
        if `full' == 1 & "`var'" == "full_time_y" {
            gen out = (`var' == 1 & inrange(incearn_nom, 24000, 30000))
        }
        else gen out = `var'

        ** Run triple-difference regression with HDFE
        reghdfe out                         /// Dependent var
                `treated'                   /// TREATMENT
                `unemp' `controls'          /// Unemp. + Demo controls
                if sample == 1              /// SAMPLE
                [aw = weight],              /// Weighted
                absorb( `did' , savefe)     /// DiD FEs
                vce(cluster state_fips)     /// State clusters
                residuals

        ** Get total of absorbed FEs
        egen fe = rowtotal(__hdfe*__)

        ** Predict with treatment ON
        qui predict yhat1_reghdfe_XB if sample == 1, xb
        gen `var'_pred_on = yhat1_reghdfe_XB + fe
        label var `var'_pred_on "Predicted `txt' status, treatment on"

        ** Temporarily set treated = 0 for counterfactual prediction
        gen tmp = treated
        qui replace treated = 0

        ** Predict with treatment OFF
        qui predict yhat2_reghdfe_XB if sample == 1, xb
        gen `var'_pred_off = yhat2_reghdfe_XB + fe
        label var `var'_pred_off "Predicted `txt' status, treatment off"

        ** Restore treated variable
        qui replace treated = tmp
        drop tmp yhat*_reghdfe_XB __hdfe*__ fe

        ** Generate predicted change in outcome
        gen `var'_pred_gap = `var'_pred_on - `var'_pred_off
        label var `var'_pred_gap "Predicted change in `txt' status"

        drop out

    } // END FULL / PART TIME LOOP

    ** -------------------------------------------------------------------------
    ** Restrict to treated CalEITC-eligible sample for fiscal calculations
    ** -------------------------------------------------------------------------

    qui replace sample = sample == 1 & ///
                         inrange(year, 2015, `p_end') & ///
                         qc_present == 1 & ///
                         state_fips == 6 & ///
                         taxsim_sim1_steitc >= 0

    ** -------------------------------------------------------------------------
    ** Assign individuals to behavioral response groups
    ** -------------------------------------------------------------------------

    ** ASSUMPTION: Two behavioral response groups
    ** 1) FT --> PT = min(delta_FT, delta_PT)
    ** 2) NW --> PT = max(0, delta_PT - delta_FT)

    ** Define groups for heterogeneity calculations
    egen het_groups = group(`het_vars') if sample == 1

    ** Initialize indicators for random samples of impacted taxpayers
    qui gen opt1 = .
    qui gen opt2 = .
    qui gen opt3 = .

    ** Loop over heterogeneity groups
    qui levelsof het_groups, local(het_list)
    foreach hl of local het_list {

        ** Display sample info
        dis "Processing heterogeneity group `hl':"
        tab `het_vars' if het_groups == `hl' [fw = weight]

        ** Get effect sizes (DELTAs)
        summ full_time_y_pred_gap [fw = weight] if sample == 1 & het_groups == `hl'
        local effect_f_`hl' = abs(`r(mean)')

        summ part_time_y_pred_gap [fw = weight] if sample == 1 & het_groups == `hl'
        local effect_p_`hl' = abs(`r(mean)')
        local n_`hl' = r(N)

        ** Generate random assignment within part-time workers
        gen rand = runiform() if sample == 1 & part_time_y == 1 & het_groups == `hl'
        sort rand
        gen tmp = 1
        bysort tmp (rand): gen cum_wt = sum(weight)
        egen max_weight = total(weight) if sample == 1 & het_groups == `hl'
        gen rand_pct = cum_wt / max_weight

        ** Option 1: All effect from non-work to part-time
        replace opt1 = 1 if het_groups == `hl' & ///
                            inrange(rand_pct, 0, `effect_p_`hl'')

        ** Option 2: All effect from full-time to part-time
        ** Note: Same individuals as option 1, only CF income differs
        replace opt2 = 1 if het_groups == `hl' & ///
                            inrange(rand_pct, 0, `effect_p_`hl'')

        ** Option 3: Use FT delta to adjudicate between channels
        local effect1_`hl' = min(`effect_f_`hl'', `effect_p_`hl'')  // FT->PT
        local effect2_`hl' = max(0, `effect_p_`hl'' - `effect_f_`hl'')  // NW->PT

        dis "  Full-time to part-time effect: `effect1_`hl''"
        dis "  Non-work to part-time effect: `effect2_`hl''"

        ** Assign: opt3=1 for FT->PT, opt3=2 for NW->PT
        replace opt3 = 1 if het_groups == `hl' & ///
                            inrange(rand_pct, 0, `effect1_`hl'')
        replace opt3 = 2 if het_groups == `hl' & ///
                            inrange(rand_pct, 0, `effect_p_`hl'') & ///
                            missing(opt3)

        drop rand rand_pct cum_wt max_weight tmp

    } // END HETEROGENEITY LOOP

    ** -------------------------------------------------------------------------
    ** Create TAXSIM input variables (dropped from working file)
    ** -------------------------------------------------------------------------

    ** Primary taxpayer age
    gen page = age
    label var page "TAXSIM primary taxpayer age"

    ** Spouse age (0 for singles)
    gen sage = 0
    label var sage "TAXSIM spouse age"

    ** Dependent exemptions (same as qc_ct, capped at 3)
    gen depx = qc_ct
    label var depx "TAXSIM dependent exemptions"

    ** Interest/dividend income (set to 0 for simplicity in MVPF simulation)
    ** Note: We're simulating at CalEITC-maximizing income, not actual income
    gen intrec = 0
    label var intrec "TAXSIM interest/dividend income"

    ** Other property income (set to 0 for simplicity)
    gen otherprop = 0
    label var otherprop "TAXSIM other property income"

    ** -------------------------------------------------------------------------
    ** Set up counterfactual and treated incomes for TAXSIM
    ** -------------------------------------------------------------------------

    ** Load CalEITC max incomes from parameter file
    merge m:1 year qc_ct using "${data}interim/caleitc_max_inc_max_cred.dta", nogen

    ** ----- Option 1: All NW --> PT -----
    gen swages_cf_opt1 = 0                  // Single, so $0
    gen ssemp_cf_opt1 = 0                   // Single, so $0
    gen psemp_cf_opt1 = 0                   // Assume changes through wages
    gen pwages_cf_opt1 = 0                  // Non-Workers (CF = $0)

    gen swages_tr_opt1 = 0
    gen ssemp_tr_opt1 = 0
    gen psemp_tr_opt1 = 0
    gen pwages_tr_opt1 = pwages_calmax      // Income at CalEITC max

    ** ----- Option 2: All FT --> PT -----
    gen swages_cf_opt2 = 0
    gen ssemp_cf_opt2 = 0
    gen psemp_cf_opt2 = 0

    ** Counterfactual FT income: binding minimum wage, median, or mean
    if `ft_pt_cf_inc' == 1 {
        gen pwages_cf_opt2 = mean_st_mw * 40 * 52  // FT at min wage
    }
    else if `ft_pt_cf_inc' == 2 {
        gen pwages_cf_opt2 = 30655                  // Median
    }
    else if `ft_pt_cf_inc' == 3 {
        gen pwages_cf_opt2 = 36413                  // Mean
    }

    gen swages_tr_opt2 = 0
    gen ssemp_tr_opt2 = 0
    gen psemp_tr_opt2 = 0
    gen pwages_tr_opt2 = pwages_calmax      // Income at CalEITC max

    ** ----- Option 3: Use FT deltas to adjudicate -----
    gen swages_cf_opt3 = 0
    gen ssemp_cf_opt3 = 0
    gen psemp_cf_opt3 = 0
    gen pwages_cf_opt3 = 0
    replace pwages_cf_opt3 = pwages_cf_opt1 if opt3 == 2  // NW->PT: CF=$0
    replace pwages_cf_opt3 = pwages_cf_opt2 if opt3 == 1  // FT->PT: CF=FT income

    gen swages_tr_opt3 = 0
    gen ssemp_tr_opt3 = 0
    gen psemp_tr_opt3 = 0
    gen pwages_tr_opt3 = pwages_calmax      // All treated at CalEITC max

    ** -------------------------------------------------------------------------
    ** Run TAXSIM for each option and treatment status
    ** -------------------------------------------------------------------------

    ** Preserve data before TAXSIM
    tempfile pre_taxsim
    save `pre_taxsim'
    clear

    ** Loop over options (1, 2, 3)
    forvalues o = 1/3 {

        ** Loop over treated (tr) and counterfactual (cf)
        foreach x in "tr" "cf" {

            ** Load data
            use `pre_taxsim', clear

            ** Keep only observations in affected groups
            qui keep if !missing(opt`o')

            ** Create unique taxsimid for this run
            sort hh_id unit_id pernum
            gegen double taxsimid = group(hh_id unit_id)

            ** Keep required variables
            keep taxsimid year page sage depx ///
                *wages_`x'_opt`o' *semp_`x'_opt`o' intrec otherprop

            ** Rename income variables for TAXSIM
            rename *wages_*_opt`o' *wages
            rename *semp_*_opt`o' *semp

            ** Set filing status and state
            gen mstat = 1       // Single
            gen state = 5       // California (SOI code)

            ** Change working directory for TAXSIM
            qui cd "${data}taxsim"

            ** Run TAXSIM
            qui taxsimlocal35, full
            clear

            ** Load results
            qui import delimited results.raw, clear

            ** Return to project directory
            qui cd "${dir}"

            ** Clean results
            destring taxsimid, replace force
            drop if missing(taxsimid)

            ** Keep relevant variables
            keep taxsimid year fiitax siitax fica v22 v23 v25 v39

            ** Rename and create variables
            rename fiitax   taxsim_fed_liab_opt`o'_`x'
            rename siitax   taxsim_st_liab_opt`o'_`x'
            rename fica     taxsim_pay_liab_opt`o'_`x'
            rename v39      taxsim_caleitc_opt`o'_`x'
            gen taxsim_ctc_opt`o'_`x' = v22 + v23
            rename v25 taxsim_fedeitc_opt`o'_`x'

            ** State liability excluding CalEITC
            gen taxsim_st_nocal_liab_opt`o'_`x' = ///
                taxsim_st_liab_opt`o'_`x' + taxsim_caleitc_opt`o'_`x'

            ** Save results
            tempfile posttaxsim_opt`o'_`x'
            qui save `posttaxsim_opt`o'_`x''
            clear

        } // END TR / CF LOOP
    } // END OPTION LOOP

    ** -------------------------------------------------------------------------
    ** Merge TAXSIM results back to main data
    ** -------------------------------------------------------------------------

    ** Load pre-TAXSIM data
    use `pre_taxsim', clear

    ** Keep only affected observations
    keep if !missing(opt1)

    ** Recreate taxsimid (must match the one created in TAXSIM loop)
    sort hh_id unit_id pernum
    gegen double taxsimid = group(hh_id unit_id)

    ** Merge all TAXSIM results
    qui merge 1:1 taxsimid year using `posttaxsim_opt1_tr', keep(master match) nogen
    qui merge 1:1 taxsimid year using `posttaxsim_opt1_cf', keep(master match) nogen
    qui merge 1:1 taxsimid year using `posttaxsim_opt2_tr', keep(master match) nogen
    qui merge 1:1 taxsimid year using `posttaxsim_opt2_cf', keep(master match) nogen
    qui merge 1:1 taxsimid year using `posttaxsim_opt3_tr', keep(master match) nogen
    qui merge 1:1 taxsimid year using `posttaxsim_opt3_cf', keep(master match) nogen

    ** Keep required variables
    keep weight opt3 year *_liab_* taxsim_fedeitc_* taxsim_ctc_* taxsim_caleitc_*

    ** -------------------------------------------------------------------------
    ** Collapse to year-group level
    ** -------------------------------------------------------------------------

    gen group = opt3
    gen pop = 1

    collapse (sum) taxsim* pop [fw = weight], by(year group)

    ** Sort and order
    sort year group
    order year group

    ** Fill in missing year-group combinations
    fillin year group
    qui replace pop = 0 if missing(pop)
    drop _fillin

    ** -------------------------------------------------------------------------
    ** Store specification information
    ** -------------------------------------------------------------------------

    gen sample = `sample'
    gen p_end = `p_end'
    gen spec_d = `spec_d'
    gen spec_u = `spec_u'
    gen spec_m = `spec_m'
    gen contrs = `contrs'
    gen hetero = `hetero'
    gen model = `model'
    gen ft_pt_cf = `ft_pt_cf_inc'
    gen full = `full'

    ** Sort and order
    sort year group sample p_end spec_* contrs hetero ft_pt_cf full
    order year group sample p_end spec_* contrs hetero ft_pt_cf full

    ** Format TAXSIM variables
    foreach var of varlist taxsim* {
        format `var' %12.0fc
    }

    ** -------------------------------------------------------------------------
    ** Label variables
    ** -------------------------------------------------------------------------

    foreach a in "opt1_cf" "opt1_tr" "opt2_cf" "opt2_tr" "opt3_cf" "opt3_tr" {

        if "`a'" == "opt1_cf" local txt_a = "no CalEITC, all NW to PT"
        if "`a'" == "opt1_tr" local txt_a = "with CalEITC, all NW to PT"
        if "`a'" == "opt2_cf" local txt_a = "no CalEITC, all FT to PT"
        if "`a'" == "opt2_tr" local txt_a = "with CalEITC, all FT to PT"
        if "`a'" == "opt3_cf" local txt_a = "no CalEITC, using FT delta"
        if "`a'" == "opt3_tr" local txt_a = "with CalEITC, using FT delta"

        foreach b in "fed_liab" "st_liab" "pay_liab" "fedeitc" "ctc" "caleitc" "st_nocal_liab" {

            if "`b'" == "fed_liab" local txt_b = "Federal IIT liability"
            if "`b'" == "st_liab" local txt_b = "State IIT liability"
            if "`b'" == "pay_liab" local txt_b = "Payroll tax liability"
            if "`b'" == "fedeitc" local txt_b = "Federal EITC"
            if "`b'" == "ctc" local txt_b = "Federal CTC"
            if "`b'" == "caleitc" local txt_b = "CalEITC"
            if "`b'" == "st_nocal_liab" local txt_b = "State IIT liability excl. CalEITC"

            label var taxsim_`b'_`a' "`txt_b', `txt_a'"

        } // END LOOP b

    } // END LOOP a

end  // END PROGRAM fiscal_cost

** =============================================================================
** (3) RUN FISCAL ANALYSIS ACROSS SPECIFICATIONS
** =============================================================================

** Initialize model counter
local ct = 1

** Fixed parameters for main analysis
local yr = ${end_year}      // End year from global
local p_sta = ${start_year} // Start year from global

** Loop over sample specifications (0=all 20-49, 1=low-ed 20-49, 2=all 20-64, 3=low-ed 20-64)
forvalues s = 0/3 {

** Loop over control state pools (0=all, 1=no eitc, 2=medicaid, 3=minwage)
forvalues c = 0/2 {

** Loop over demographic controls (0/1)
forvalues d = 0/1 {

** Loop over unemployment controls (0/1)
forvalues u = 0/1 {

** Loop over minimum wage controls (0/1)
forvalues m = 0/1 {

** Loop over heterogeneity (0=none, 1=year, 2=qc_ct)
forvalues h = 0/2 {

** Loop over FT-PT counterfactual income (1=min wage, 2=median, 3=mean)
forvalues i = 1/3 {

** Loop over full effect option (0=entire, 1=discrete only)
forvalues f = 0/1 {

    dis "=============================================="
    dis "Running Model `ct'"
    dis "  Sample: `s', Controls: `c', Demo: `d', Unemp: `u', MW: `m'"
    dis "  Hetero: `h', CF Inc: `i', Full: `f'"
    dis "=============================================="

    ** Run fiscal cost program
    fiscal_cost `s'     /// Sample
                `i'     /// FT-PT counterfactual income
                `p_sta' /// Period start
                `yr'    /// Period end
                `d'     /// Demographics
                `u'     /// Unemployment
                `m'     /// Minimum wage
                `c'     /// Control states
                `h'     /// Heterogeneity
                `f'     /// Full effect option
                `ct'    // Model count

    ** Save or append results
    if `ct' == 1 {
        save "${data}interim/acs_fiscal_cost.dta", replace
    }
    else {
        append using "${data}interim/acs_fiscal_cost.dta"
        save "${data}interim/acs_fiscal_cost.dta", replace
    }

    ** Update model counter
    local ct = `ct' + 1

} // END FULL LOOP

} // END FT-PT CF INCOME LOOP

} // END HETEROGENEITY LOOP

} // END MINIMUM WAGE LOOP

} // END UNEMPLOYMENT LOOP

} // END DEMOGRAPHICS LOOP

} // END CONTROL STATES LOOP

} // END SAMPLE LOOP

** =============================================================================
** (4) PROCESS RESULTS AND CALCULATE MVPF
** =============================================================================

** Load results
use "${data}interim/acs_fiscal_cost.dta", clear

** -------------------------------------------------------------------------
** Add labels
** -------------------------------------------------------------------------

label var sample "Sample"
label define lb_sample 0 "All, 20-49" 1 "Low-ed, 20-40" 2 "All, 20-49" 3 "Low-ed, 20-64", modify
label values sample lb_sample

label var p_end "End year of analysis period"
label var spec_d "Includes demographic controls"
label var spec_u "Includes unemployment controls"
label var spec_m "Includes minimum wage controls"

label var contrs "Control state pool"
label define lb_contrs  0 "States without EITC changes"     ///
                        1 "States without any EITCs"        ///
                        2 "Medicaid expansion states"       ///
                        3 "2014 minimum wage changes", modify
label values contrs lb_contrs

label var hetero "Heterogeneous treatment effect"
label define lb_hetero  0 "No heterogeneity"    ///
                        1 "By tax year"         ///
                        2 "By count of QC"      ///
                        3 "By count of adults in HH", modify
label values hetero lb_hetero

label var ft_pt_cf "FT-to-PT counterfactual income"
label define lb_ft_pt_cf 1 "Binding minimum wage" 2 "$27,000", modify
label values ft_pt_cf lb_ft_pt_cf

label var full "Full-time effect specification"
label define lb_full 0 "Entire effect" 1 "Discrete effect only ($24K-$30K)"
label values full lb_full

label define lb_groups 1 "Full-time to part-time" 2 "Non-working to part-time", modify
label values group lb_groups
label var group "Behavioral response group (for option 3)"
label var model "Model number"
label var pop "Weighted population"

** -------------------------------------------------------------------------
** Generate CPI adjustment factors (base year = 2017)
** -------------------------------------------------------------------------

gen cpi = .
replace cpi = 245.121 / 255.653 if year == 2019
replace cpi = 245.121 / 251.100 if year == 2018
replace cpi = 245.121 / 245.121 if year == 2017
replace cpi = 245.121 / 240.005 if year == 2016
replace cpi = 245.121 / 237.002 if year == 2015
label var cpi "CPI adjustment factor (2017 USD)"

** -------------------------------------------------------------------------
** Add direct program costs (CalEITC expenditures)
** -------------------------------------------------------------------------

gen direct_costs = .
replace direct_costs = 200000000 if year == 2015
replace direct_costs = 201000000 if year == 2016
replace direct_costs = 348451029 if year == 2017
replace direct_costs = 401578130 if year == 2018
replace direct_costs = 743740147 if year == 2019
label var direct_costs "Annual cost of the CalEITC (nominal USD)"

gen direct_costs_real = direct_costs * cpi
label var direct_costs_real "Annual cost of the CalEITC (2017 USD)"

** Sort and order
sort model year group
order model year group

** -------------------------------------------------------------------------
** Calculate fiscal externalities (treatment effect - counterfactual)
** -------------------------------------------------------------------------

foreach a in "fed_liab" "st_liab" "pay_liab" "fedeitc" "ctc" "caleitc" "st_nocal_liab" {

    if "`a'" == "fed_liab" local txt = "Federal IIT liability"
    if "`a'" == "st_liab" local txt = "State IIT liability"
    if "`a'" == "pay_liab" local txt = "Payroll tax liability"
    if "`a'" == "fedeitc" local txt = "Federal EITC"
    if "`a'" == "ctc" local txt = "Federal CTC"
    if "`a'" == "caleitc" local txt = "CalEITC"
    if "`a'" == "st_nocal_liab" local txt = "State IIT liability excl. CalEITC"

    ** Option 1: All NW --> PT
    gen long effect_`a'_opt1 = taxsim_`a'_opt1_tr - taxsim_`a'_opt1_cf
    label var effect_`a'_opt1 "Effect on `txt', all NW to PT"
    replace effect_`a'_opt1 = 0 if missing(effect_`a'_opt1)

    ** Option 2: All FT --> PT
    gen long effect_`a'_opt2 = taxsim_`a'_opt2_tr - taxsim_`a'_opt2_cf
    label var effect_`a'_opt2 "Effect on `txt', all FT to PT"
    replace effect_`a'_opt2 = 0 if missing(effect_`a'_opt2)

    ** Option 3: Use FT deltas
    gen long effect_`a'_opt3 = taxsim_`a'_opt3_tr - taxsim_`a'_opt3_cf
    label var effect_`a'_opt3 "Effect on `txt', using FT deltas"
    replace effect_`a'_opt3 = 0 if missing(effect_`a'_opt3)

} // END VAR LOOP

** -------------------------------------------------------------------------
** Convert effects to real (2017) dollars
** -------------------------------------------------------------------------

foreach a in "fed_liab" "st_liab" "pay_liab" "fedeitc" "ctc" "caleitc" "st_nocal_liab" {

    if "`a'" == "fed_liab" local txt = "Federal IIT liability"
    if "`a'" == "st_liab" local txt = "State IIT liability"
    if "`a'" == "pay_liab" local txt = "Payroll tax liability"
    if "`a'" == "fedeitc" local txt = "Federal EITC"
    if "`a'" == "ctc" local txt = "Federal CTC"
    if "`a'" == "caleitc" local txt = "CalEITC"
    if "`a'" == "st_nocal_liab" local txt = "State IIT liability excl. CalEITC"

    gen long effect_`a'_opt1_real = effect_`a'_opt1 * cpi
    label var effect_`a'_opt1_real "Effect on `txt', all NW to PT (2017 USD)"

    gen long effect_`a'_opt2_real = effect_`a'_opt2 * cpi
    label var effect_`a'_opt2_real "Effect on `txt', all FT to PT (2017 USD)"

    gen long effect_`a'_opt3_real = effect_`a'_opt3 * cpi
    label var effect_`a'_opt3_real "Effect on `txt', using FT deltas (2017 USD)"

} // END VAR LOOP

** Save intermediate results
save "${data}interim/acs_fiscal_cost.dta", replace

** Export as Excel for reference
export excel using "${data}interim/acs_fiscal_cost.xlsx", ///
     firstrow(variables) sheet("stata_export", replace)

** =============================================================================
** (5) COLLAPSE AND CALCULATE MVPF
** =============================================================================

** Load data
use "${data}interim/acs_fiscal_cost.dta", clear

** Scale to millions for readability
foreach var of varlist effect_* direct_costs* {
    replace `var' = `var' / 1000000
}

** Collapse to model-year level (sum effects across groups)
collapse (sum) effect_*_real pop (mean) direct_costs*_real, ///
    by(year model sample hetero spec_* p_end contrs ft_pt_cf full)

** Collapse to model level (sum across years)
collapse (sum) effect_* direct_costs* pop, ///
    by(model sample hetero spec_* p_end contrs ft_pt_cf full)

** -------------------------------------------------------------------------
** Calculate MVPF components
** -------------------------------------------------------------------------

** Numerator: Willingness-to-pay
** = Direct transfer value - lost CalEITC from behavioral change
gen numerator = direct_costs_real - effect_caleitc_opt3_real
label var numerator "MVPF Numerator (Willingness-to-Pay, $M 2017)"

** Denominator: Net fiscal cost (progressive)
** Start with direct costs, subtract fiscal externalities

** Denominator 1: Direct cost only
gen denominator_1 = direct_costs_real
label var denominator_1 "MVPF Denom: Direct CalEITC cost only"

** Denominator 2: Add federal IIT changes
gen denominator_2 = denominator_1 - effect_fed_liab_opt3_real
label var denominator_2 "MVPF Denom: + Federal IIT changes"

** Denominator 3: Add payroll tax changes
gen denominator_3 = denominator_2 - effect_pay_liab_opt3_real
label var denominator_3 "MVPF Denom: + Payroll tax changes"

** Denominator 4: Add state IIT changes (full fiscal externality)
gen denominator_4 = denominator_3 - effect_st_nocal_liab_opt3_real
label var denominator_4 "MVPF Denom: + State IIT changes (full)"

** -------------------------------------------------------------------------
** Calculate MVPF ratios
** -------------------------------------------------------------------------

gen mvpf_1 = numerator / denominator_1
gen mvpf_2 = numerator / denominator_2
gen mvpf_3 = numerator / denominator_3
gen mvpf_4 = numerator / denominator_4

label var mvpf_1 "MVPF (direct cost only)"
label var mvpf_2 "MVPF (+ federal IIT)"
label var mvpf_3 "MVPF (+ payroll tax)"
label var mvpf_4 "MVPF (full fiscal externality)"

** Save collapsed results
save "${data}interim/acs_fiscal_cost_collapse.dta", replace

** =============================================================================
** (6) GENERATE SUMMARY OUTPUTS
** =============================================================================

** Create output directory if needed
capture mkdir "${results}paper"
capture mkdir "${results}paper/fiscal"

** -------------------------------------------------------------------------
** Summary statistics for preferred specification
** -------------------------------------------------------------------------

** Preferred specification:
** - Sample: Low-education (1)
** - Demographics: On (1)
** - Unemployment: On (1)
** - Minimum wage: On (1)
** - Control states: All (0)
** - Heterogeneity: By QC count (2)
** - CF income: Minimum wage (1)
** - Full effect: Entire (0)

dis "=============================================="
dis "MVPF Summary Statistics"
dis "=============================================="

summ mvpf_4 if sample == 1 & spec_d == 1 & spec_u == 1 & spec_m == 1 & ///
               contrs == 0 & hetero == 2 & ft_pt_cf == 1 & full == 0
local mvpf_pref = `r(mean)'
dis "Preferred specification MVPF (min wage CF): `mvpf_pref'"

summ mvpf_4 if sample == 1 & spec_d == 1 & spec_u == 1 & spec_m == 1 & ///
               contrs == 0 & hetero == 2 & ft_pt_cf == 2 & full == 0
local mvpf_pref2 = `r(mean)'
dis "Preferred specification MVPF ($27K CF): `mvpf_pref2'"

summ mvpf_4
dis "Overall MVPF: Mean=`r(mean)', SD=`r(sd)', Min=`r(min)', Max=`r(max)'"
dis "=============================================="

** Note: Detailed figures are generated by separate scripts:
** - 02_fig_mvpf_dist.do: MVPF distribution histogram
** - 02_fig_mvpf_spillovers.do: Fiscal spillovers bar charts

** -------------------------------------------------------------------------
** Summary table: MVPF by key specification choices
** -------------------------------------------------------------------------

** Collapse to get mean MVPF by specification dimension
preserve

** By sample
collapse (mean) mvpf_mean = mvpf_4 (sd) mvpf_sd = mvpf_4 (count) n = mvpf_4, by(sample)
list, clean noobs
export delimited "${results}tables/mvpf_by_sample.csv", replace

restore
preserve

** By control states
collapse (mean) mvpf_mean = mvpf_4 (sd) mvpf_sd = mvpf_4 (count) n = mvpf_4, by(contrs)
list, clean noobs
export delimited "${results}tables/mvpf_by_contrs.csv", replace

restore
preserve

** By heterogeneity
collapse (mean) mvpf_mean = mvpf_4 (sd) mvpf_sd = mvpf_4 (count) n = mvpf_4, by(hetero)
list, clean noobs
export delimited "${results}tables/mvpf_by_hetero.csv", replace

restore

** =============================================================================
** END
** =============================================================================

clear
log close log_02_mvpf

dis "=============================================="
dis "MVPF Analysis Complete"
dis "Results saved to: ${data}interim/acs_fiscal_cost_collapse.dta"
dis "Figures saved to: ${results}paper/fiscal/"
dis "=============================================="
