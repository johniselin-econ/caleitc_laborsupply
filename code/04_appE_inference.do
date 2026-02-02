/*******************************************************************************
File Name:      04_appE_inference.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix E alternative inference procedures
                Calculates p-values using:
                - Cluster-robust variance estimator (CRVE)
                - Wild cluster bootstrap (WCB)
                - Randomization inference wild bootstrap (RIWB)
                - Block bootstrap with Ferman-Pinto (2019) correction

                References:
                - Ferman and Pinto (2019): Inference in Differences-in-Differences
                  with Few Treated Groups and Heteroskedasticity
                - MacKinnon and Webb (2019): Wild Bootstrap Inference for
                  Wildly Different Cluster Sizes

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appE_inference
log using "${logs}04_appE_inference_log_${date}", ///
    name(log_04_appE_inference) replace text

** Ensure tmp directory exists
cap mkdir "${data}tmp"

** =============================================================================
** Define parameters
** =============================================================================

** Sample period
local start = 2012
local end = 2017

** Define outcomes
local outcomes "full_time_y part_time_y"

** Bootstrap parameters (adjust for debug mode)
if ${debug} == 1 {
    local B = 10
    local B_ri = 4
    local debug_text "_debug"
}
else {
    local B = 1000
    local B_ri = 100
    local debug_text ""
}

** =============================================================================
** PROGRAM 1: Ferman-Pinto Block Bootstrap
** Implements block bootstrap with and without Ferman-Pinto (2019) adjustment
** at the individual level, building on FP (2019) replication package
** =============================================================================

capture program drop ferman_pinto_boot_ind
program define ferman_pinto_boot_ind, rclass

    args Y X DiD C U CL T G W B DATA

    ** Preserve data
    preserve

    ** STEP 1: Estimate DID equation
    reghdfe `Y' `X' `U' [aw = `W'], vce(cluster `CL') absorb(`DiD' `C')

    ** Store alpha
    local alpha_hat = _b[`X']

    ** STEP 2: Estimate DID equation assuming treatment = 0
    reghdfe `Y' `U' [aw = `W'], vce(cluster `CL') ///
        absorb(`DiD' `C', savefe) resid

    ** Estimate residuals
    qui predict eta_iqjt, resid

    ** STEP 3: Collapse to YEAR X STATE X QC level
    keep `T' `CL' `W' eta_iqjt `G'

    ** Generate sum of weights (P_qjt) for State X Year X QC
    bysort `CL' `T' `G': egen P_qjt = total(`W')

    ** Generate eta for State X Year X QC
    ** eta_qjt = sum_i [(w_iqjt / P_qjt) * eta_iqjt]
    gen tmp_eta_iqjt = eta_iqjt * (`W' / P_qjt)
    bysort `CL' `T' `G': egen eta_qjt = total(tmp_eta_iqjt)

    ** Generate treatment indicators
    gen post = (`T' >= 2015)
    gen ca = (`CL' == 6)

    ** Calculate W weights (DiD weighting)
    gen temp = .

    forvalues p = 0/1 {
        forvalues q = 0/1 {
            qui egen P_q1`p' = total(`W') if ca == 1 & post == `p' & `G' == `q'
            qui replace temp = (P_qjt / P_q1`p') if ca == 1 & post == `p' & `G' == `q'
            drop P_q1`p'
        }
    }

    ** Fill in Pr_q1t
    egen Pr_q1t = mean(temp), by(`T' `G')
    drop temp

    ** Generate W_did (components will sum together)
    gen W_did = .
    qui replace W_did = Pr_q1t * eta_qjt if post == 1 & `G' == 1
    qui replace W_did = -Pr_q1t * eta_qjt if post == 1 & `G' == 0
    qui replace W_did = -Pr_q1t * eta_qjt if post == 0 & `G' == 1
    qui replace W_did = Pr_q1t * eta_qjt if post == 0 & `G' == 0

    ** Calculate q_qjt = Pr_q1t^2 * sum(weight^2) / (P_qjt^2)
    gen tmp = `W'^2
    bysort `CL' `T' `G': egen omega2 = sum(tmp)
    gen q = (Pr_q1t^2) * omega2 / (P_qjt^2)

    ** Collapse to state level
    keep `CL' `T' `G' ca W_did q P_qjt
    duplicates drop `CL' `T' `G' ca W_did q P_qjt, force
    collapse (mean) ca (sum) W_did q P_qjt, by(`CL')

    ** Calculate variance of W_did
    qui summ W_did [aw = P_qjt], detail
    local mean = r(mean)
    gen W2 = (W_did - `mean')^2

    ** Estimate var(W|M)
    reg W2 q [pw = P_qjt]
    predict var_M

    local beta_q = _b[q]
    local const = _b[_cons]

    ** Finite sample correction
    summ var_M
    local min = r(min)

    ** Apply correction if minimum predicted variance is negative
    if `min' < 0 {
        if `beta_q' < 0 {
            qui replace var_M = 1
        }
        else if `const' < 0 {
            qui replace var_M = q
        }
    }

    gen W_normalized = W_did / sqrt(var_M)

    ** Prepare for bootstrap
    egen id = group(`CL')
    sort id
    qui summ id
    local N = r(N)

    ** Run residual bootstrap with and without correction
    forvalues b = 1/`B' {

        ** Generate bootstrap sample
        gen h1 = uniform()
        gen h2 = 1 + int((`N' - 1 + 1) * h1)

        ** Fill in W_did from bootstrap assigned state (uncorrected)
        gen W_tilde = W_did[h2]

        ** Fill in W_did from bootstrap assigned state (corrected)
        gen W_tilde_corrected = W_normalized[h2] * sqrt(var_M)

        ** Calculate alphas for treated
        qui summ W_tilde if ca == 1
        local W_tilde_1_unadj = r(mean)

        qui summ W_tilde_corrected if ca == 1
        local W_tilde_1_adj = r(mean)

        ** Calculate alphas for control
        qui summ W_tilde if ca == 0 [aw = P_qjt]
        local W_tilde_0_unadj = r(mean)

        qui summ W_tilde_corrected if ca == 0 [aw = P_qjt]
        local W_tilde_0_adj = r(mean)

        ** Calculate R statistics
        local r`b'_1 = (`W_tilde_1_unadj' - `W_tilde_0_unadj')
        local r`b'_2 = (`W_tilde_1_adj' - `W_tilde_0_adj')

        drop h1 h2 *tilde*
    }

    ** STEP 5: Calculate p-values
    clear
    set obs `B'

    if "`C'" == "" local c_text = 0
    else local c_text = 1
    if "`U'" == "" local u_text = 0
    else local u_text = 1

    gen n = _n
    qui gen alpha1 = .
    qui gen alpha2 = .
    qui gen B = `B'
    qui gen out = "`Y'"
    qui gen C = `c_text'
    qui gen U = `u_text'

    forvalues b = 1(1)`B' {
        qui replace alpha1 = `r`b'_1' if n == `b'
        qui replace alpha2 = `r`b'_2' if n == `b'
    }

    ** Generate alpha squared
    gen alpha1_sq = alpha1^2
    gen alpha2_sq = alpha2^2
    gen alpha = `alpha_hat'
    gen alpha_sq = alpha^2

    ** Generate p-values
    gen p_1 = alpha1_sq > alpha_sq if !missing(alpha1) & !missing(alpha)
    gen p_2 = alpha2_sq > alpha_sq if !missing(alpha2) & !missing(alpha)

    ** Calculate mean p-values
    qui summ p_1
    local p_without = `r(mean)'
    qui summ p_2
    local p_with = `r(mean)'

    ** Display results
    di _n "Ferman and Pinto (2019) P-Value, w/o correction = " %4.3f `p_without'
    di "Ferman and Pinto (2019) P-Value, with correction = " %4.3f `p_with'

    ** Save data if requested
    if "`DATA'" != "" {
        save "`DATA'", replace
        clear
    }
    else {
        di "No save option specified, raw output lost"
        clear
    }

    ** Restore
    restore

    ** Return results
    return scalar p_with = `p_with'
    return scalar p_without = `p_without'

end


** =============================================================================
** PROGRAM 2: Randomization Inference Wild Bootstrap
** Implements wild cluster randomization inference from MacKinnon and Webb (2019)
** =============================================================================

capture program drop ri_bs
program define ri_bs, rclass

    args Y X DiD C U CL W B PT DATA

    ** STEP 1: Estimate DID equation
    qui reghdfe `Y' `X' `U' [aw = `W'], vce(cluster `CL') absorb(`DiD' `C')

    ** Store beta and t-statistic
    local b_hat = _b[`X']
    local t_hat = _b[`X'] / _se[`X']
    local b_hat_0 = `b_hat'
    local t_hat_0 = `t_hat'

    ** STEP 2: Construct t_hat_j using RI inference
    bysort `CL': egen ever_treat = max(`X')
    gen never_treat = (ever_treat == 0)
    drop ever_treat

    ** Define control states for RI (exclude California, FIPS = 6)
    egen control_states = group(`CL') if `CL' != 6
    qui summ control_states
    local n = `r(max)'
    qui levelsof control_states, local(contr_states)

    ** Loop over control states
    foreach j of local contr_states {
        di "RI: `j'"

        ** Define placebo treatment
        gen ptreat = (control_states == `j') & (`PT' == 1)

        ** Estimate DID
        qui reghdfe `Y' ptreat `U' if never_treat == 1 [aw = `W'], ///
            vce(cluster `CL') absorb(`DiD' `C')

        local b_hat_`j' = _b[ptreat]
        local t_hat_`j' = _b[ptreat] / _se[ptreat]

        drop ptreat
    }

    drop never_treat

    ** STEP 3: Estimate DID assuming treatment = 0
    qui reghdfe `Y' `U' [aw = `W'], vce(cluster `CL') ///
        absorb(`DiD' `C', savefe) resid

    qui predict temp_er, resid
    qui predict temp_xbr, xbd

    ** STEP 4: Bootstrap for each RI permutation
    ** Note: j=0 represents actual treatment (California), j=1..n are placebo states
    forvalues j = 0(1)`n' {
        di "RI: `j'"

        ** For j=0, use actual treated state; for j>0, use placebo control state
        if `j' == 0 {
            gen ptreat = (`CL' == 6) & (`PT' == 1)
        }
        else {
            gen ptreat = (control_states == `j') & (`PT' == 1)
        }

        forvalues b = 1(1)`B' {
            di "BS: `b'"

            ** Generate Rademacher weights at cluster level
            sort `CL'
            by `CL': gen tmp_uni = uniform()
            qui by `CL': gen tmp_pos = tmp_uni[1] < 0.5

            ** Transform residuals
            qui gen tmp_ernew = (2 * tmp_pos - 1) * temp_er
            qui gen tmp_ywild = temp_xbr + tmp_ernew

            ** Estimate model with wild Y
            qui reghdfe tmp_ywild ptreat `U' [aw = `W'], ///
                vce(cluster `CL') absorb(`DiD' `C')

            local b_hat_`j'_`b' = _b[ptreat]
            local t_hat_`j'_`b' = _b[ptreat] / _se[ptreat]

            drop tmp_*
        }

        drop ptreat
    }

    cap drop control_states
    cap drop _reghdfe_resid
    cap drop temp_*

    ** STEP 5: Calculate p-values
    preserve
    clear

    local ct = `B' * (`n' + 1)
    set obs `ct'

    gen n = _n - 1
    gen b = .
    gen j = .
    gen t = .
    gen beta = .
    gen t_0 = `t_hat_0'
    gen beta_0 = `b_hat_0'
    gen t_0_abs = abs(t_0)
    gen beta_0_abs = abs(beta_0)

    local ct = 1
    forvalues j = 0(1)`n' {
        forvalues b = 1(1)`B' {
            qui replace j = `j' if n == `ct'
            qui replace b = `b' if n == `ct'
            qui replace t = `t_hat_`j'_`b'' if n == `ct'
            qui replace beta = `b_hat_`j'_`b'' if n == `ct'
            local ct = `ct' + 1
        }
    }

    ** Calculate absolute values
    gen t_abs = abs(t)
    gen beta_abs = abs(beta)

    ** Generate indicators
    gen ind_t = t_abs > t_0_abs
    gen ind_beta = beta_abs > beta_0_abs

    ** Calculate p-values
    egen sum_ind_t = total(ind_t)
    egen sum_ind_beta = total(ind_beta)
    gen S = _N
    gen p_t = sum_ind_t / S
    gen p_beta = sum_ind_beta / S

    qui summ p_t
    local p_t = `r(mean)'
    qui summ p_beta
    local p_beta = `r(mean)'

    ** Save if requested
    if "`DATA'" != "" {
        save "`DATA'", replace
        clear
    }
    else {
        di "No save option specified"
    }

    restore

    ** Display results
    di _n "WBRI-b P-Value = " %4.3f `p_beta'
    di "WBRI-t P-Value = " %4.3f `p_t'

    ** Return results
    return scalar p_t = `p_t'
    return scalar p_beta = `p_beta'

end


** =============================================================================
** Load data and prepare sample
** =============================================================================

use if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        state_status > 0 & ///
        education <= 3 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", replace

** Rescale outcome variables to percentage points
foreach out of local outcomes {
    replace `out' = `out' * 100
}

** Create main DID variables
gen ca = (state_fips == 6)
gen childXyearXca = cond(qc_present == 1 & ca == 1, year, 2014)
gen treated = (state_fips == 6 & qc_present == 1 & year >= 2015)
gen post = (year >= 2015)
label var treated "ATE"

** Update adults per HH (cap at 3)
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** Generate minimum wage variable
gen minwage = mean_st_mw
label var minwage "Binding state minimum wage"

** =============================================================================
** Define specifications
** =============================================================================

** SPEC 1: Basic triple-diff
local did1 "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"
local unemp1 ""
local controls1 ""

** SPEC 2: Add demographic controls
local did2 "`did1'"
local unemp2 ""
local controls2 "education age_bracket minage_qc race_group hispanic hh_adult_ct"

** SPEC 3: Add unemployment controls
local did3 "`did1'"
local unemp3 "c.state_unemp#i.qc_ct"
local controls3 "`controls2'"

** SPEC 4: Add minimum wage controls
local did4 "`did1'"
local unemp4 "`unemp3' c.minwage#i.qc_ct"
local controls4 "`controls2'"

** For wild cluster bootstrap (areg variant)
egen grp_state_year = group(state_fips year)
egen grp_state_qc = group(state_fips qc_ct)
egen grp_year_qc = group(year qc_ct)

local absorb1_areg "grp_state_year"
local did1_areg "i.state_fips i.qc_ct i.year i.grp_state_qc i.grp_year_qc"
local controls1_areg ""

local absorb2_areg "`absorb1_areg'"
local did2_areg "`did1_areg'"
local controls2_areg "i.education i.age_bracket i.minage_qc i.race_group i.hispanic i.hh_adult_ct"

local absorb3_areg "`absorb1_areg'"
local did3_areg "`did1_areg'"
local controls3_areg "`controls2_areg'"

local absorb4_areg "`absorb1_areg'"
local did4_areg "`did1_areg'"
local controls4_areg "`controls2_areg'"

** For randomization inference
gen pot_treat = (qc_present == 1) & (year >= 2015)

** =============================================================================
** Run regressions with alternative inference
** =============================================================================

local i = 1

foreach out of local outcomes {

    di "Outcome: `out'"

    forvalues spec = 1(1)4 {

        di _n "Specification: `spec'"

        ** Set specification locals
        local did "`did`spec''"
        local unemp "`unemp`spec''"
        local controls "`controls`spec''"

        local absorb "`absorb`spec'_areg'"
        local did_areg "`did`spec'_areg'"
        local controls_areg "`controls`spec'_areg'"

        ** ---------------------------------------------------------------------
        ** Wild Cluster Bootstrap
        ** ---------------------------------------------------------------------
        wildbootstrap ///
            areg `out' treated `unemp' `did_areg' `controls_areg' ///
            [aw = weight], ///
            absorb(`absorb') ///
            cluster(state_fips) ///
            coefficients(treated) ///
            reps(`B') ///
            rseed(${seed})

        local p_wcbs = e(wboot)[1,3]

        ** ---------------------------------------------------------------------
        ** Randomization Inference Wild Bootstrap
        ** ---------------------------------------------------------------------
        ri_bs `out' treated "`did'" "`controls'" "`unemp'" ///
            state_fips weight `B_ri' pot_treat ///
            "${data}tmp/data_`out'_`spec'_riwcbs`debug_text'.dta"

        local p_riwcbs_b = `r(p_beta)'
        local p_riwcbs_t = `r(p_t)'

        ** ---------------------------------------------------------------------
        ** Block Bootstrap (Ferman-Pinto)
        ** ---------------------------------------------------------------------
        ferman_pinto_boot_ind `out' treated "`did'" "`controls'" "`unemp'" ///
            state_fips year qc_present weight `B' ///
            "${data}tmp/data_`out'_`spec'_fp2019`debug_text'.dta"

        local p_block_fp = `r(p_with)'
        local p_block = `r(p_without)'

        ** ---------------------------------------------------------------------
        ** Main regression with CRVE
        ** ---------------------------------------------------------------------
        eststo `out'_`spec': ///
            reghdfe `out' treated `unemp' [aw = weight], ///
            absorb(`did' `controls') ///
            vce(cluster state_fips)

        ** Calculate CRVE p-value
        local beta = _b[treated]
        local t = _b[treated] / _se[treated]
        local p_crve = 2 * ttail(e(df_r), abs(`t'))
        estadd scalar p_crve = `p_crve'

        ** Add alternative p-values
        estadd scalar p_wcbs = `p_wcbs'
        estadd scalar p_riwcbs_b = `p_riwcbs_b'
        estadd scalar p_riwcbs_t = `p_riwcbs_t'
        estadd scalar p_block = `p_block'
        estadd scalar p_block_fp = `p_block_fp'
    }

    ** -------------------------------------------------------------------------
    ** Export results table
    ** -------------------------------------------------------------------------

    local stats_list "N p_crve p_wcbs p_riwcbs_b p_riwcbs_t p_block p_block_fp"
    local stats_fmt "%9.0fc %9.3fc %9.3fc %9.3fc %9.3fc %9.3fc %9.3fc"

    local stats_labels `" "  Observations" "'
    local stats_labels `" `stats_labels' "  CRVE P-Value" "'
    local stats_labels `" `stats_labels' "  WCBS P-Value" "'
    local stats_labels `" `stats_labels' "  RIWB-t P-Value" "'
    local stats_labels `" `stats_labels' "  RIWB-b P-Value" "'
    local stats_labels `" `stats_labels' "  BB P-Value" "'
    local stats_labels `" `stats_labels' "  Corrected BB P-Value" "'

    ** Export to local results
    esttab `out'_* using ///
        "${results}tables/tab_appE_tab1_`i'`debug_text'.tex", ///
        booktabs fragment nobaselevels replace nomtitles nonumbers ///
        stats(`stats_list', ///
            fmt("`stats_fmt'") labels(`stats_labels')) ///
        b(1) se(1) label order(treated) keep(treated) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        prehead("\\ \midrule") nolines

    ** Export to Overleaf
    if ${overleaf} == 1 {
        esttab `out'_* using ///
            "${ol_tab}tab_appE_tab1_`i'`debug_text'.tex", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers ///
            stats(`stats_list', ///
                fmt("`stats_fmt'") labels(`stats_labels')) ///
            b(1) se(1) label order(treated) keep(treated) ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("\\ \midrule") nolines
    }

    ** Update counter
    local i = `i' + 1
}

** =============================================================================
** End
** =============================================================================

clear
log close log_04_appE_inference
