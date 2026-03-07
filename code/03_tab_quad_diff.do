/*******************************************************************************
File Name:      03_tab_quad_diff.do
Creator:        John Iselin
Date Update:    March 2026

Purpose:        Creates Quadruple-Difference Table
                Expands sample to include college-educated women. Uses
                noncollege as the 4th dimension to net out any CA x post x QC
                confounder common to both education groups.

                The 4-way interaction (noncollege x CA x post x QC) identifies
                the CalEITC-specific effect.

                Saturated 3-way FEs absorb all lower-order interactions and
                economic controls (unemployment, minimum wage), so only 2 specs
                are needed: (1) FEs only, (2) FEs + demographic controls.

                Uses utility programs: setup_did_vars, run_triple_diff,
                add_spec_indicators, add_table_stats, export_results

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_tab_quad_diff
log using "${logs}03_tab_quad_diff_log_${date}", ///
    name(log_03_tab_quad_diff) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Demographic controls (exclude education — absorbed by noncollege FE interactions)
local controls "age_bracket minage_qc race_group hispanic hh_adult_ct"

** =============================================================================
** Load data — full sample (college + non-college)
** =============================================================================

** Cannot use load_baseline_sample (restricts to education < 4)
** Load all single women ages 20-49, both education groups
use weight $outcomes incearn_real `controls' $unemp $minwage qc_* year ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status education ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        state_status > 0 & ///
        inrange(year, ${start_year}, ${end_year}) ///
    using "${data}final/acs_working_file.dta", clear

di _n "Loaded quad-diff sample (college + non-college)"
di "  N = " _N

** Create DID variables using utility
setup_did_vars

** =============================================================================
** Create quadruple-difference variables
** =============================================================================

** Education dimension
gen noncollege = (education < 4)
label var noncollege "Non-college educated"

** Quad-diff treatment: noncollege x CA x post x QC
gen quad_treated = (noncollege == 1 & ca == 1 & post == 1 & qc_present == 1)
label var quad_treated "Quadruple-Diff ATE"

** =============================================================================
** Define fixed effects
** =============================================================================

** Saturated 3-way FEs: all 4 combinations of 3-way interactions
** These subsume all lower-order interactions AND absorb economic controls
** (unemployment x QC and minwage x QC are absorbed by state#year#qc_ct)
local quad_fes "state_fips#year#qc_ct state_fips#year#noncollege state_fips#qc_ct#noncollege year#qc_ct#noncollege"

** =============================================================================
** Run regressions — Employment outcomes
** =============================================================================

eststo clear

local ct = 1

foreach out of global outcomes {

    ** Scale outcome to percentage points
    replace `out' = `out' * 100

    ** ------------------------------------------------------------------
    ** SPEC 1: 3-way FEs only (no individual controls)
    ** ------------------------------------------------------------------
    eststo est_`out'_1: ///
        reghdfe `out' quad_treated [aw=weight], ///
            absorb(`quad_fes') vce(cluster $clustervar)

    ** Pre-period treated mean (non-college, CA, with QC)
    qui summ `out' if post == 0 & ca == 1 & qc_present == 1 & noncollege == 1 [aw=weight]
    estadd scalar ymean = r(mean)

    ** Implied effect
    qui count if quad_treated == 1
    local n_treated = r(N)
    estadd scalar C = `n_treated' * _b[quad_treated] / 100

    ** Spec indicators (only 2 specs for quad-diff)
    estadd local s1 "Yes"
    estadd local s2 "No"

    ** ------------------------------------------------------------------
    ** SPEC 2: 3-way FEs + demographic controls
    ** ------------------------------------------------------------------
    eststo est_`out'_2: ///
        reghdfe `out' quad_treated [aw=weight], ///
            absorb(`quad_fes' `controls') vce(cluster $clustervar)

    qui summ `out' if post == 0 & ca == 1 & qc_present == 1 & noncollege == 1 [aw=weight]
    estadd scalar ymean = r(mean)

    qui count if quad_treated == 1
    local n_treated = r(N)
    estadd scalar C = `n_treated' * _b[quad_treated] / 100

    estadd local s1 "Yes"
    estadd local s2 "Yes"

    ** ------------------------------------------------------------------
    ** Export table
    ** ------------------------------------------------------------------
    export_results est_`out'_1 est_`out'_2, ///
        filename("tab_quad_diff_`ct'.tex") ///
        statslist("N r2_a ymean C") ///
        statsfmt("%9.0fc %9.3fc %9.1fc %9.0fc") ///
        label1("  Observations") ///
        label2("  Adj. R-Square") ///
        label3("  Treated group mean in pre-period") ///
        label4("  Implied employment effect") ///
        keepvars("quad_treated") ordervars("quad_treated")

    ** Spec indicators table (first outcome only)
    if `ct' == 1 {
        export_results est_`out'_1 est_`out'_2, ///
            filename("tab_quad_diff_end.tex") ///
            statslist("s1 s2") ///
            statsfmt("%9s %9s") ///
            label1("  Saturated 3-way FEs") ///
            label2("  Add Demographic Controls") ///
            keepvars("quad_treated") ordervars("quad_treated") ///
            cellsnone
    }

    local ct = `ct' + 1
}

** =============================================================================
** Run regressions — Earnings (OLS only, all observations)
** =============================================================================

** Handle missing earned income
replace incearn_real = 0 if incearn_real == .

** SPEC 1: FEs only
eststo est_earn_1: ///
    reghdfe incearn_real quad_treated [aw=weight], ///
        absorb(`quad_fes') vce(cluster $clustervar)

qui summ incearn_real if post == 0 & ca == 1 & qc_present == 1 & noncollege == 1 [aw=weight]
estadd scalar ymean = r(mean)
estadd local s1 "Yes"
estadd local s2 "No"

** SPEC 2: FEs + demographic controls
eststo est_earn_2: ///
    reghdfe incearn_real quad_treated [aw=weight], ///
        absorb(`quad_fes' `controls') vce(cluster $clustervar)

qui summ incearn_real if post == 0 & ca == 1 & qc_present == 1 & noncollege == 1 [aw=weight]
estadd scalar ymean = r(mean)
estadd local s1 "Yes"
estadd local s2 "Yes"

** Export earnings table
export_results est_earn_1 est_earn_2, ///
    filename("tab_quad_diff_earn.tex") ///
    statslist("N r2_a ymean") ///
    statsfmt("%9.0fc %9.3fc %9.0fc") ///
    label1("  Observations") ///
    label2("  Adj. R-Square") ///
    label3("  Treated group mean in pre-period") ///
    bdigits(1) sedigits(1) ///
    keepvars("quad_treated") ordervars("quad_treated")

** =============================================================================
** End
** =============================================================================

clear
log close log_03_tab_quad_diff
