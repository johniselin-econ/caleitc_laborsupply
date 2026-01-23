/*******************************************************************************
File Name:      sdid_wt.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Defines the sdid_wt program for weighted Synthetic DID estimation

                This program:
                - Runs SDID separately for each treated unit
                - Computes population-weighted average of unit-specific ATTs
                - Uses bootstrap (clustered by unit) for standard errors
                - Supports time-varying covariates

                Usage:
                    sdid_wt outcome unit_id time_var treatment_var, ///
                        weight(weight_var) [covyn(0/1) bs(#) covarlist(varlist)]

Project: CalEITC Labor Supply Effects
*******************************************************************************/

capture program drop sdid_wt
program define sdid_wt, rclass

    ** Syntax
    syntax varlist(min=4 max=4 numeric) [if], ///
        weight(varname numeric) ///
        [covyn(integer 0) bs(integer 50) covarlist(varlist numeric)]

    ** Preserve data
    preserve

    ** Keep observations meeting if condition
    if "`if'" != "" keep `if'

    ** Set up tempvars
    tempvar evertreated treated_units

    ** Confirm variables exist
    foreach var of varlist `varlist' `covarlist' `weight' {
        capture describe `var'
        assert _rc == 0
    }

    ** Elements of varlist: outcome, unit_id, time_var, treatment
    token `varlist'

    ** Create list of treated units
    bysort `2': egen `evertreated' = max(`4')
    egen `treated_units' = group(`2') if `evertreated' == 1
    qui summ `treated_units'
    local c_max = `r(max)'

    dis "Number of treated units: `c_max'"

    ** Loop over each treated unit
    foreach ct of num 1/`c_max' {

        ** Count
        dis "Running SDID for treated unit `ct'"

        if `covyn' == 1 {
            ** Run SDID with covariates
            qui sdid `1' `2' `3' `4' if ///
                (`treated_units' == `ct' | `evertreated' == 0), ///
                vce(noinference) covariates(`covarlist', projected)
        }
        if `covyn' == 0 {
            ** Run SDID without covariates
            qui sdid `1' `2' `3' `4' if ///
                (`treated_units' == `ct' | `evertreated' == 0), ///
                vce(noinference)
        }

        ** Store ATE
        local ate_`ct' = `e(ATT)'

        ** Store weight (from first time period)
        qui summ `3'
        local min_t = `r(min)'
        qui summ `weight' if `3' == `min_t' & `treated_units' == `ct'
        local wt_`ct' = `r(mean)'

    }

    ** Drop variables
    drop `treated_units' `evertreated'

    ** Create temporary file
    tempfile main_dta
    save `main_dta'

    clear

    ** Create dataset of ATEs and weights
    set obs `c_max'

    gen ct = _n
    qui gen ate = .
    qui gen wt = .

    ** Fill in dataset
    foreach ct of num 1/`c_max' {
        qui replace ate = `ate_`ct'' if ct == `ct'
        qui replace wt = `wt_`ct'' if ct == `ct'
    }

    ** Collapse to get weighted ATE
    collapse (mean) ate [aw = wt]

    qui summ ate
    local tmp_ate = `r(mean)'
    dis "ATE: `tmp_ate'"

    ** Close data
    clear

    ** =========================================================================
    ** Bootstrap procedure for standard errors
    ** =========================================================================

    local b = 1

    ** Loop over bootstrap samples
    while `b' <= `bs' {

        dis "Bootstrap loop: `b'"

        ** Load data
        use `main_dta', clear

        ** Construct bootstrap sample (clustered by unit)
        qui bsample, cluster(`2') idcluster(id2)

        ** Make sure that we observe some treated and control units
        qui count if `4' == 0
        local r1 = r(N)
        qui count if `4' == 1
        local r2 = r(N)

        ** If we have both treated and control units
        if (`r1' != 0 & `r2' != 0) {

            ** Create list of treated units in bootstrap sample
            bysort id2: egen `evertreated' = max(`4')
            egen `treated_units' = group(id2) if `evertreated' == 1
            qui summ `treated_units'
            local c_max_bs = `r(max)'

            dis "Number of treated units in bootstrap sample `b': `c_max_bs'"

            ** Loop over each treated unit
            foreach ct of num 1/`c_max_bs' {

                qui dis "Running SDID for treated unit `ct'"

                if `covyn' == 1 {
                    ** Run SDID with covariates
                    qui sdid `1' id2 `3' `4' if ///
                        (`treated_units' == `ct' | `evertreated' == 0), ///
                        vce(noinference) covariates(`covarlist', projected)
                }
                if `covyn' == 0 {
                    ** Run SDID without covariates
                    qui sdid `1' id2 `3' `4' if ///
                        (`treated_units' == `ct' | `evertreated' == 0), ///
                        vce(noinference)
                }

                ** Store ATE
                local ate_bs_`ct' = `e(ATT)'

                ** Store weight
                qui summ `3'
                local min_t = `r(min)'
                qui summ `weight' if `3' == `min_t' & `treated_units' == `ct'
                local wt_bs_`ct' = `r(mean)'

            }

            ** Clear data
            clear

            ** Create dataset
            qui set obs `c_max_bs'

            gen ct = _n
            qui gen ate = .
            qui gen wt = .

            ** Fill in
            foreach ct of num 1/`c_max_bs' {
                qui replace ate = `ate_bs_`ct'' if ct == `ct'
                qui replace wt = `wt_bs_`ct'' if ct == `ct'
            }

            ** Collapse to get weighted ATE
            collapse (mean) ate [aw = wt]

            qui summ ate
            local ate_`b' = `r(mean)'

        }
        ** If no treatment or no control units, then missing
        else {
            local ate_`b' = .
        }

        ** Close data
        clear

        local ++b

    }

    ** =========================================================================
    ** Calculate bootstrap standard error
    ** =========================================================================

    clear

    ** Create dataset of bootstrap results
    qui set obs `bs'
    qui gen ct = _n
    qui gen ate = .

    ** Fill in bootstrap ATEs
    forval ct = 1/`bs' {
        qui replace ate = `ate_`ct'' if ct == `ct'
    }

    ** Generate standard deviation
    drop if missing(ate)
    egen sd = sd(ate)
    summ
    gen se = sd
    qui keep if ct == 1
    summ se
    local tmp_se = `r(mean)'

    ** Return results
    return scalar ate = `tmp_ate'
    return scalar se = `tmp_se'
    display "ATE: `tmp_ate'"
    display "SE: `tmp_se'"

    ** Restore data
    restore

end
