/*******************************************************************************
File Name:      03_tab_sim_inst.do
Creator:        John Iselin
Date Update:    March 2026

Purpose:        Simulated instrument IV estimation (Gruber & Saez 2002)

                Instruments actual state EITC benefits (Sim 1, individual-level,
                from observed characteristics) with simulated state EITC benefits
                (Sim 2, cell-level, from CPI-projected 2014 base year).

                Sim 2 varies only with policy parameters x predetermined
                demographics (year x state x QC x marital x educ x age x sex),
                purging behavioral responses from the endogenous variable.

                FE structure: Cell dimensions that define the instrument
                (education, age_bracket) are absorbed as FEs rather than
                entered as linear controls. This ensures identification comes
                from within-cell policy variation over time, not cross-cell
                demographic composition. Remaining controls (minage_qc,
                race_group, hispanic, hh_adult_ct) vary within cells and
                are included as regressors.

                Structure:
                  Section 1: Descriptive table — actual vs simulated EITC by cell
                  Section 2: First stage — simulated EITC predicts actual EITC
                  Section 3: Reduced form — simulated EITC on outcomes
                  Section 4: 2SLS — actual EITC instrumented by simulated EITC

Project: CalEITC Labor Supply Effects

NOTE — ARCHIVED (March 2026):
    The IV results confirm the main triple-difference employment effect
    but the part-time reallocation effect (significant in the main spec)
    disappears. Three reasons:

    1. Different estimand: The main spec identifies CalEITC eligibility
       effects (extensive margin). The IV estimates a per-$1000 EITC
       dollar effect, which weights differently across the QC distribution.

    2. Kink-point incentives not captured: The FT/PT reallocation is driven
       by nonlinear incentives at EITC schedule kink points. The continuous
       dollar instrument averages over these, attenuating the margin where
       the action is.

    3. Imprecision: IV SEs are ~8x larger than the main spec (e.g., 4.7pp
       vs 0.6pp for part-time). The 95% CI [-14.6, +4.7] contains the
       main estimate of +3.4pp — so the IV does not reject the main result,
       it simply lacks power to detect it.

    Conclusion: The IV validates the overall employment effect but is not
    well-suited to decompose the FT/PT margin. Archived for reference.
*******************************************************************************/

** Start log file
capture log close log_03_tab_sim_inst
log using "${logs}03_tab_sim_inst_log_${date}", name(log_03_tab_sim_inst) replace text

** =============================================================================
** Define specifications
** =============================================================================

** Define outcome variables
local outcomes "employed_y full_time_y part_time_y"

** Controls that vary WITHIN instrument cells
** (minage_qc, race, hispanic, hh_adult_ct are not cell dimensions)
local within_controls "minage_qc race_group hispanic hh_adult_ct"

** Cell dimensions to absorb as FEs
** (education and age_bracket define the instrument cells)
local cell_fes "education age_bracket"

** Define economic controls
local unemp "state_unemp"
local minwage "mean_st_mw"

** Define cluster variable
local clustervar "state_fips"

** Define start and end dates
local start = ${start_year}
local end = ${end_year}

** Base triple-diff FEs
local did_base "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"

** Full FEs: base + cell dimensions absorbed
local did_cell "`did_base' `cell_fes'"

** =============================================================================
** Load data
** =============================================================================

** Load ACS data (includes both Sim 1 and Sim 2 EITC variables)
use weight `outcomes' `within_controls' `unemp' `minwage' qc_* year ///
    female married in_school age_sample_20_49 citizen_test state_fips state_status ///
    education age_bracket ///
    taxsim_sim1_fedeitc taxsim_sim1_steitc ///
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

** Create standard DID variables
gen ca = (state_fips == 6)
gen post = (year > 2014)
gen treated = (qc_present == 1 & ca == 1 & post == 1)
label var treated "ATE"

** Cap adults per HH at 3
replace hh_adult_ct = 3 if hh_adult_ct > 3
capture label drop lb_adult_ct
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** -------------------------------------------------------------------------
** Construct EITC variables (scaled to $1,000s)
** -------------------------------------------------------------------------

** Actual state EITC from observed characteristics (Sim 1)
** Individual-level, reflects actual earnings choices
gen actual_steitc = taxsim_sim1_steitc / 1000
label var actual_steitc "Actual CalEITC ($1,000s)"

** Simulated state EITC from CPI-projected base year (Sim 2)
** Cell-level, reflects only policy variation x predetermined demographics
gen sim_steitc = taxsim_sim2_steitc / 1000
label var sim_steitc "Simulated CalEITC ($1,000s)"

** Zero out non-CA state EITC (instrument should only capture CalEITC variation)
replace actual_steitc = 0 if state_fips != 6
replace sim_steitc = 0 if state_fips != 6

di _n "Loaded baseline sample: `start'-`end', N = " _N

** =============================================================================
** Section 1: Descriptive Table — Actual vs Simulated EITC by Cell
** =============================================================================

di _n _dup(70) "="
di "DESCRIPTIVE STATISTICS: ACTUAL VS SIMULATED EITC BY CELL"
di _dup(70) "="

** -------------------------------------------------------------------------
** Panel A: By year (CA, with QC)
** -------------------------------------------------------------------------

di _n "Panel A: Mean EITC by year (CA, QC > 0)"
table year if ca == 1 & qc_present == 1 [aw = weight], ///
    stat(mean actual_steitc) stat(mean sim_steitc) ///
    stat(sd actual_steitc) stat(sd sim_steitc) ///
    stat(freq)

** -------------------------------------------------------------------------
** Panel B: By QC count (CA, post period)
** -------------------------------------------------------------------------

di _n "Panel B: Mean EITC by QC count (CA, post-2014)"
table qc_ct if ca == 1 & post == 1 & qc_present == 1 [aw = weight], ///
    stat(mean actual_steitc) stat(mean sim_steitc) ///
    stat(sd actual_steitc) stat(sd sim_steitc) ///
    stat(freq)

** -------------------------------------------------------------------------
** Panel C: By education (CA, post period, with QC)
** -------------------------------------------------------------------------

di _n "Panel C: Mean EITC by education (CA, post-2014, QC > 0)"
table education if ca == 1 & post == 1 & qc_present == 1 [aw = weight], ///
    stat(mean actual_steitc) stat(mean sim_steitc) ///
    stat(sd actual_steitc) stat(sd sim_steitc) ///
    stat(freq)

** -------------------------------------------------------------------------
** Panel D: By age bracket (CA, post period, with QC)
** -------------------------------------------------------------------------

di _n "Panel D: Mean EITC by age bracket (CA, post-2014, QC > 0)"
table age_bracket if ca == 1 & post == 1 & qc_present == 1 [aw = weight], ///
    stat(mean actual_steitc) stat(mean sim_steitc) ///
    stat(sd actual_steitc) stat(sd sim_steitc) ///
    stat(freq)

** -------------------------------------------------------------------------
** Export descriptive table as CSV
** -------------------------------------------------------------------------

preserve

    ** Collapse to cell means for CA, with QC
    keep if ca == 1 & qc_present == 1

    collapse (mean) mean_actual = actual_steitc mean_sim = sim_steitc ///
             (sd)   sd_actual = actual_steitc sd_sim = sim_steitc ///
             (rawsum) N = weight ///
        [aw = weight], by(year qc_ct education)

    ** Compute ratio
    gen ratio = mean_actual / mean_sim if mean_sim > 0

    ** Label
    label var mean_actual "Mean actual CalEITC ($1,000s)"
    label var mean_sim "Mean simulated CalEITC ($1,000s)"
    label var sd_actual "SD actual"
    label var sd_sim "SD simulated"
    label var ratio "Actual/Simulated ratio"
    label var N "Weighted N"

    ** Sort
    sort year qc_ct education

    ** Export
    export delimited "${results}tables/tab_sim_inst_descriptive.csv", replace

    di _n "Exported descriptive table: tab_sim_inst_descriptive.csv"

restore

** -------------------------------------------------------------------------
** Summary stats to log
** -------------------------------------------------------------------------

di _n _dup(70) "-"
di "Summary: CA treated group (QC > 0)"
di _dup(70) "-"

di _n "Pre-period (year <= 2014):"
qui summ actual_steitc if ca == 1 & qc_present == 1 & post == 0 [aw = weight]
di "  Actual CalEITC:    mean = " %6.4f r(mean) "  sd = " %6.4f r(sd)
qui summ sim_steitc if ca == 1 & qc_present == 1 & post == 0 [aw = weight]
di "  Simulated CalEITC: mean = " %6.4f r(mean) "  sd = " %6.4f r(sd)

di _n "Post-period (year > 2014):"
qui summ actual_steitc if ca == 1 & qc_present == 1 & post == 1 [aw = weight]
di "  Actual CalEITC:    mean = " %6.4f r(mean) "  sd = " %6.4f r(sd)
qui summ sim_steitc if ca == 1 & qc_present == 1 & post == 1 [aw = weight]
di "  Simulated CalEITC: mean = " %6.4f r(mean) "  sd = " %6.4f r(sd)

di _n "Control states (QC > 0, all years):"
qui summ actual_steitc if ca == 0 & qc_present == 1 [aw = weight]
di "  Actual CalEITC:    mean = " %6.4f r(mean) "  (should be ~0)"
qui summ sim_steitc if ca == 0 & qc_present == 1 [aw = weight]
di "  Simulated CalEITC: mean = " %6.4f r(mean) "  (should be ~0)"

** =============================================================================
** Section 2: First Stage — Simulated EITC Predicts Actual EITC
** =============================================================================

di _n _dup(70) "="
di "FIRST STAGE: SIMULATED EITC -> ACTUAL EITC"
di _dup(70) "="

** Note: First stage estimates stored as fs_* and NOT cleared until end of file

** Spec 1: Triple-diff FEs + cell FEs only
eststo fs_1: reghdfe actual_steitc sim_steitc [aw = weight], ///
    absorb(`did_cell') vce(cluster `clustervar')

estadd local fe_did "Yes"
estadd local fe_cell "Yes"
estadd local fe_controls "No"
estadd scalar fstat = e(F)

** Spec 2: Add within-cell controls
eststo fs_2: reghdfe actual_steitc sim_steitc ///
    i.(`within_controls') [aw = weight], ///
    absorb(`did_cell') vce(cluster `clustervar')

estadd local fe_did "Yes"
estadd local fe_cell "Yes"
estadd local fe_controls "Yes"
estadd scalar fstat = e(F)

** Spec 3: Add economic controls
eststo fs_3: reghdfe actual_steitc sim_steitc ///
    i.(`within_controls') c.`unemp'#i.qc_ct c.`minwage'#i.qc_ct [aw = weight], ///
    absorb(`did_cell') vce(cluster `clustervar')

estadd local fe_did "Yes"
estadd local fe_cell "Yes"
estadd local fe_controls "Yes + Econ"
estadd scalar fstat = e(F)

** Display first stage results
di _n "First stage coefficients (sim_steitc -> actual_steitc):"
forvalues s = 1/3 {
    estimates restore fs_`s'
    di "  Spec `s': b = " %8.4f _b[sim_steitc] ///
       "  SE = " %8.4f _se[sim_steitc] ///
       "  F = " %8.1f e(F)
}

** Export first stage table
local fs_stats "N r2_a fstat fe_did fe_cell fe_controls"
local fs_fmt "%9.0fc %9.3fc %9.1fc %9s %9s %9s"

local fs_labels `" "  Observations" "'
local fs_labels `" `fs_labels' "  Adj. R-Square" "'
local fs_labels `" `fs_labels' "  F-statistic" "'
local fs_labels `" `fs_labels' "  Triple-Diff FEs" "'
local fs_labels `" `fs_labels' "  Cell FEs (Educ, Age)" "'
local fs_labels `" `fs_labels' "  Controls" "'

esttab fs_1 fs_2 fs_3 using ///
    "${results}tables/tab_sim_inst_fs.tex", ///
    booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
    stats(`fs_stats', fmt(`fs_fmt') labels(`fs_labels')) ///
    b(3) se(3) label order(sim_steitc) keep(sim_steitc) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    prehead("\\ \midrule")

if ${overleaf} == 1 {
    esttab fs_1 fs_2 fs_3 using ///
        "${ol_tab}tab_sim_inst_fs.tex", ///
        booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
        stats(`fs_stats', fmt(`fs_fmt') labels(`fs_labels')) ///
        b(3) se(3) label order(sim_steitc) keep(sim_steitc) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        prehead("\\ \midrule")
}

** =============================================================================
** Section 3: Reduced Form — Simulated EITC on Employment Outcomes
** =============================================================================

di _n _dup(70) "="
di "REDUCED FORM: SIMULATED EITC -> EMPLOYMENT"
di _dup(70) "="

** Scale outcomes to percentage points
foreach out of local outcomes {
    replace `out' = `out' * 100
}

local ct = 1

foreach out of local outcomes {

    ** Spec 1: Triple-diff + cell FEs only
    eststo rf_`out'_1: reghdfe `out' sim_steitc [aw = weight], ///
        absorb(`did_cell') vce(cluster `clustervar')

    estadd local fe_did "Yes"
    estadd local fe_cell "Yes"
    estadd local fe_controls "No"

    ** Spec 2: Add within-cell controls
    eststo rf_`out'_2: reghdfe `out' sim_steitc ///
        i.(`within_controls') [aw = weight], ///
        absorb(`did_cell') vce(cluster `clustervar')

    estadd local fe_did "Yes"
    estadd local fe_cell "Yes"
    estadd local fe_controls "Yes"

    ** Spec 3: Full controls
    eststo rf_`out'_3: reghdfe `out' sim_steitc ///
        i.(`within_controls') c.`unemp'#i.qc_ct c.`minwage'#i.qc_ct [aw = weight], ///
        absorb(`did_cell') vce(cluster `clustervar')

    estadd local fe_did "Yes"
    estadd local fe_cell "Yes"
    estadd local fe_controls "Yes + Econ"

    ** Store pre-period treated mean
    qui summ `out' if qc_present == 1 & ca == 1 & post == 0 [aw = weight]
    estadd scalar ymean = r(mean)

    ** Export reduced form table for this outcome
    local rf_stats "N r2_a ymean fe_did fe_cell fe_controls"
    local rf_fmt "%9.0fc %9.3fc %9.1fc %9s %9s %9s"

    local rf_labels `" "  Observations" "'
    local rf_labels `" `rf_labels' "  Adj. R-Square" "'
    local rf_labels `" `rf_labels' "  Treated group mean (pre)" "'
    local rf_labels `" `rf_labels' "  Triple-Diff FEs" "'
    local rf_labels `" `rf_labels' "  Cell FEs (Educ, Age)" "'
    local rf_labels `" `rf_labels' "  Controls" "'

    esttab rf_`out'_1 rf_`out'_2 rf_`out'_3 using ///
        "${results}tables/tab_sim_inst_rf_`ct'.tex", ///
        booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
        stats(`rf_stats', fmt(`rf_fmt') labels(`rf_labels')) ///
        b(3) se(3) label order(sim_steitc) keep(sim_steitc) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        prehead("\\ \midrule")

    if ${overleaf} == 1 {
        esttab rf_`out'_1 rf_`out'_2 rf_`out'_3 using ///
            "${ol_tab}tab_sim_inst_rf_`ct'.tex", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
            stats(`rf_stats', fmt(`rf_fmt') labels(`rf_labels')) ///
            b(3) se(3) label order(sim_steitc) keep(sim_steitc) ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("\\ \midrule")
    }

    local ct = `ct' + 1
}

** =============================================================================
** Section 4: 2SLS — Actual EITC Instrumented by Simulated EITC
** =============================================================================

di _n _dup(70) "="
di "IV/2SLS: ACTUAL EITC (INSTRUMENTED BY SIMULATED EITC) -> EMPLOYMENT"
di _dup(70) "="

local ct = 1

foreach out of local outcomes {

    ** Spec 1: Triple-diff + cell FEs only
    eststo iv_`out'_1: ivreghdfe `out' ///
        (actual_steitc = sim_steitc) [aw = weight], ///
        absorb(`did_cell') cluster(`clustervar')

    estadd local fe_did "Yes"
    estadd local fe_cell "Yes"
    estadd local fe_controls "No"
    estadd scalar fstat_first = e(widstat)

    ** Pre-period mean
    qui summ `out' if qc_present == 1 & ca == 1 & post == 0 [aw = weight]
    estadd scalar ymean = r(mean)

    ** Spec 2: Add within-cell controls
    eststo iv_`out'_2: ivreghdfe `out' i.(`within_controls') ///
        (actual_steitc = sim_steitc) [aw = weight], ///
        absorb(`did_cell') cluster(`clustervar')

    estadd local fe_did "Yes"
    estadd local fe_cell "Yes"
    estadd local fe_controls "Yes"
    estadd scalar fstat_first = e(widstat)

    qui summ `out' if qc_present == 1 & ca == 1 & post == 0 [aw = weight]
    estadd scalar ymean = r(mean)

    ** Spec 3: Full controls
    eststo iv_`out'_3: ivreghdfe `out' i.(`within_controls') ///
        c.`unemp'#i.qc_ct c.`minwage'#i.qc_ct ///
        (actual_steitc = sim_steitc) [aw = weight], ///
        absorb(`did_cell') cluster(`clustervar')

    estadd local fe_did "Yes"
    estadd local fe_cell "Yes"
    estadd local fe_controls "Yes + Econ"
    estadd scalar fstat_first = e(widstat)

    qui summ `out' if qc_present == 1 & ca == 1 & post == 0 [aw = weight]
    estadd scalar ymean = r(mean)

    ** Export IV table for this outcome
    local iv_stats "N ymean fstat_first fe_did fe_cell fe_controls"
    local iv_fmt "%9.0fc %9.1fc %9.1fc %9s %9s %9s"

    local iv_labels `" "  Observations" "'
    local iv_labels `" `iv_labels' "  Treated group mean (pre)" "'
    local iv_labels `" `iv_labels' "  KP Wald F-stat" "'
    local iv_labels `" `iv_labels' "  Triple-Diff FEs" "'
    local iv_labels `" `iv_labels' "  Cell FEs (Educ, Age)" "'
    local iv_labels `" `iv_labels' "  Controls" "'

    esttab iv_`out'_1 iv_`out'_2 iv_`out'_3 using ///
        "${results}tables/tab_sim_inst_iv_`ct'.tex", ///
        booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
        stats(`iv_stats', fmt(`iv_fmt') labels(`iv_labels')) ///
        b(3) se(3) label order(actual_steitc) keep(actual_steitc) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        prehead("\\ \midrule")

    if ${overleaf} == 1 {
        esttab iv_`out'_1 iv_`out'_2 iv_`out'_3 using ///
            "${ol_tab}tab_sim_inst_iv_`ct'.tex", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
            stats(`iv_stats', fmt(`iv_fmt') labels(`iv_labels')) ///
            b(3) se(3) label order(actual_steitc) keep(actual_steitc) ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("\\ \midrule")
    }

    local ct = `ct' + 1
}

** =============================================================================
** Section 5: Summary
** =============================================================================

di _n _dup(70) "="
di "SUMMARY OF SIMULATED INSTRUMENT RESULTS"
di _dup(70) "="

di _n "Approach: Instrument actual CalEITC (from observed earnings) with"
di "simulated CalEITC (from CPI-projected 2014 base year, cell-level)."
di "Both variables in $1,000s. Coefficients: pp change per $1,000 CalEITC."
di ""
di "Cell dimensions (education, age_bracket) absorbed as FEs."
di "Identification: within-cell policy variation over time."

di _n "First stage (Sim -> Actual, full spec):"
estimates restore fs_3
di "  b = " %8.4f _b[sim_steitc] "  SE = " %8.4f _se[sim_steitc] ///
   "  F = " %8.1f e(F)

di _n "2SLS results (full spec):"
foreach out in employed_y full_time_y part_time_y {
    estimates restore iv_`out'_3
    di "  `out': b = " %6.3f _b[actual_steitc] ///
       "  SE = " %6.3f _se[actual_steitc] ///
       "  KP F = " %6.1f e(widstat)
}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_tab_sim_inst
