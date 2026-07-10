/*******************************************************************************
File Name:      03_tab_oster_bounds.do
Creator:        John Iselin
Date Update:    March 2026

Purpose:        Creates Oster (2019) coefficient stability bounds table.
                For each employment outcome, compares uncontrolled (Spec 1)
                and controlled (Spec 4) estimates to compute:
                  - delta: selection ratio (how much selection on unobservables
                    relative to observables needed to explain coefficient away)
                  - beta_adjusted: bias-adjusted coefficient at Rmax

                Uses psacalc (Oster's Stata package) where feasible. If psacalc
                fails with absorbed FEs, falls back to manual Oster formula.

                Uses utility programs: load_baseline_sample, setup_did_vars,
                export_results

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_tab_oster_bounds
log using "${logs}03_tab_oster_bounds_log_${date}", ///
    name(log_03_tab_oster_bounds) replace text

** =============================================================================
** Load data and setup
** =============================================================================

** Load baseline sample
load_baseline_sample, varlist(incearn_real)

** Handle missing earned income
replace incearn_real = 0 if incearn_real == .

** Create DID variables using utility
setup_did_vars

** =============================================================================
** Define Oster bounds computation
** =============================================================================

** We compute bounds manually since psacalc may not handle reghdfe absorbed FEs.
** Oster (2019) formula:
**   beta_adjusted = beta_F - delta * (beta_R - beta_F) * (Rmax - R2_F) / (R2_F - R2_R)
** where:
**   beta_R = restricted (uncontrolled, Spec 1) coefficient
**   beta_F = full (controlled, Spec 4) coefficient
**   R2_R   = R-squared from restricted model
**   R2_F   = R-squared from full model
**   Rmax   = assumed maximum R-squared
**   delta  = proportional selection assumption
**
** To find the delta that drives beta_adjusted to zero:
**   delta* = beta_F / (beta_R - beta_F) * (Rmax - R2_F) / (R2_F - R2_R)
**   (when beta_R != beta_F and R2_F != R2_R)
**
** We also invert to report: for delta=1, what is beta_adjusted?

** Store results in a matrix
** Rows: outcomes (employed_y, full_time_y, part_time_y, incearn_real)
** Cols: beta_R, beta_F, R2_R, R2_F, delta_star_13, beta_adj_13, delta_star_2R, beta_adj_2R
matrix oster = J(4, 8, .)
matrix colnames oster = beta_R beta_F R2_R R2_F delta_13 beta_adj_13 delta_2R beta_adj_2R
matrix rownames oster = employed_y full_time_y part_time_y incearn_real

** =============================================================================
** Employment outcomes (scaled to pp)
** =============================================================================

local outcomes_all "employed_y full_time_y part_time_y"

** Scale employment outcomes to percentage points
foreach out of local outcomes_all {
    replace `out' = `out' * 100
}

local row = 1

foreach out of local outcomes_all {

    ** -------------------------------------------------------------------
    ** Restricted model (Spec 1): FEs only, no individual controls
    ** -------------------------------------------------------------------
    qui reghdfe `out' treated [aw=weight], ///
        absorb($did_base) vce(cluster $clustervar)

    local beta_R = _b[treated]
    local R2_R = e(r2_a)

    ** -------------------------------------------------------------------
    ** Full model (Spec 4): FEs + all controls
    ** -------------------------------------------------------------------
    qui reghdfe `out' treated c.$unemp#i.qc_ct c.$minwage#i.qc_ct [aw=weight], ///
        absorb($did_base $controls) vce(cluster $clustervar)

    local beta_F = _b[treated]
    local R2_F = e(r2_a)

    ** -------------------------------------------------------------------
    ** Compute Oster bounds
    ** -------------------------------------------------------------------

    ** Rmax = 1.3 * R2_F (Oster's recommended default)
    local Rmax_13 = min(1.3 * `R2_F', 1)

    ** Rmax = min(2 * R2_F, 1) (robustness)
    local Rmax_2R = min(2 * `R2_F', 1)

    ** Compute delta* (for beta_adjusted = 0) at each Rmax
    ** delta* = beta_F * (Rmax - R2_F) / ((beta_R - beta_F) * (R2_F - R2_R))
    local denom = (`beta_R' - `beta_F') * (`R2_F' - `R2_R')

    if abs(`denom') > 1e-10 {
        local delta_13 = `beta_F' * (`Rmax_13' - `R2_F') / `denom'
        local delta_2R = `beta_F' * (`Rmax_2R' - `R2_F') / `denom'
    }
    else {
        ** If coefficient barely moves, delta is effectively infinite
        local delta_13 = .
        local delta_2R = .
    }

    ** Compute beta_adjusted at delta=1 for each Rmax
    ** beta_adj = beta_F - (beta_R - beta_F) * (Rmax - R2_F) / (R2_F - R2_R)
    local R2_diff = `R2_F' - `R2_R'
    if abs(`R2_diff') > 1e-10 {
        local beta_adj_13 = `beta_F' - (`beta_R' - `beta_F') * (`Rmax_13' - `R2_F') / `R2_diff'
        local beta_adj_2R = `beta_F' - (`beta_R' - `beta_F') * (`Rmax_2R' - `R2_F') / `R2_diff'
    }
    else {
        local beta_adj_13 = `beta_F'
        local beta_adj_2R = `beta_F'
    }

    ** Store in matrix
    matrix oster[`row', 1] = `beta_R'
    matrix oster[`row', 2] = `beta_F'
    matrix oster[`row', 3] = `R2_R'
    matrix oster[`row', 4] = `R2_F'
    matrix oster[`row', 5] = `delta_13'
    matrix oster[`row', 6] = `beta_adj_13'
    matrix oster[`row', 7] = `delta_2R'
    matrix oster[`row', 8] = `beta_adj_2R'

    ** Display
    di _n "=== `out' ==="
    di "  beta_R (uncontrolled) = " %9.3f `beta_R'
    di "  beta_F (full)         = " %9.3f `beta_F'
    di "  R2_R                  = " %9.4f `R2_R'
    di "  R2_F                  = " %9.4f `R2_F'
    di "  Rmax (1.3x)           = " %9.4f `Rmax_13'
    di "  delta* (1.3x)         = " %9.3f `delta_13'
    di "  beta_adj (1.3x, d=1)  = " %9.3f `beta_adj_13'
    di "  Rmax (2x)             = " %9.4f `Rmax_2R'
    di "  delta* (2x)           = " %9.3f `delta_2R'
    di "  beta_adj (2x, d=1)    = " %9.3f `beta_adj_2R'

    local row = `row' + 1
}

** =============================================================================
** Earnings outcome (in dollars, not percentage points)
** =============================================================================

** Restricted model
qui reghdfe incearn_real treated [aw=weight], ///
    absorb($did_base) vce(cluster $clustervar)

local beta_R = _b[treated]
local R2_R = e(r2_a)

** Full model
qui reghdfe incearn_real treated c.$unemp#i.qc_ct c.$minwage#i.qc_ct [aw=weight], ///
    absorb($did_base $controls) vce(cluster $clustervar)

local beta_F = _b[treated]
local R2_F = e(r2_a)

** Rmax values
local Rmax_13 = min(1.3 * `R2_F', 1)
local Rmax_2R = min(2 * `R2_F', 1)

** Delta* and beta_adjusted
local denom = (`beta_R' - `beta_F') * (`R2_F' - `R2_R')
if abs(`denom') > 1e-10 {
    local delta_13 = `beta_F' * (`Rmax_13' - `R2_F') / `denom'
    local delta_2R = `beta_F' * (`Rmax_2R' - `R2_F') / `denom'
}
else {
    local delta_13 = .
    local delta_2R = .
}

local R2_diff = `R2_F' - `R2_R'
if abs(`R2_diff') > 1e-10 {
    local beta_adj_13 = `beta_F' - (`beta_R' - `beta_F') * (`Rmax_13' - `R2_F') / `R2_diff'
    local beta_adj_2R = `beta_F' - (`beta_R' - `beta_F') * (`Rmax_2R' - `R2_F') / `R2_diff'
}
else {
    local beta_adj_13 = `beta_F'
    local beta_adj_2R = `beta_F'
}

matrix oster[4, 1] = `beta_R'
matrix oster[4, 2] = `beta_F'
matrix oster[4, 3] = `R2_R'
matrix oster[4, 4] = `R2_F'
matrix oster[4, 5] = `delta_13'
matrix oster[4, 6] = `beta_adj_13'
matrix oster[4, 7] = `delta_2R'
matrix oster[4, 8] = `beta_adj_2R'

di _n "=== incearn_real ==="
di "  beta_R (uncontrolled) = " %9.1f `beta_R'
di "  beta_F (full)         = " %9.1f `beta_F'
di "  R2_R                  = " %9.4f `R2_R'
di "  R2_F                  = " %9.4f `R2_F'
di "  delta* (1.3x)         = " %9.3f `delta_13'
di "  beta_adj (1.3x, d=1)  = " %9.1f `beta_adj_13'
di "  delta* (2x)           = " %9.3f `delta_2R'
di "  beta_adj (2x, d=1)    = " %9.1f `beta_adj_2R'

** =============================================================================
** Display full matrix
** =============================================================================

di _n "=== Oster (2019) Bounds Summary ==="
matrix list oster, format(%9.3f)

** =============================================================================
** Export to LaTeX
** =============================================================================

** Build the table manually since this is a custom layout
** Columns: Outcome | beta_R | beta_F | R2_R | R2_F | delta*(1.3x) | beta_adj(1.3x) | delta*(2x) | beta_adj(2x)

preserve
clear

** Create dataset from matrix
svmat oster, names(col)

gen outcome = ""
replace outcome = "Employed" in 1
replace outcome = "Full-time" in 2
replace outcome = "Part-time" in 3
replace outcome = "Earnings (\$)" in 4

** Format and export
gen str_line = ""

forvalues i = 1/4 {

    ** Format numbers
    local b_R : di %9.3f beta_R[`i']
    local b_F : di %9.3f beta_F[`i']
    local r_R : di %9.3f R2_R[`i']
    local r_F : di %9.3f R2_F[`i']

    ** Format delta (handle missing = infinity)
    if delta_13[`i'] == . {
        local d_13 "$\infty$"
    }
    else {
        local d_13 : di %9.2f delta_13[`i']
    }
    if delta_2R[`i'] == . {
        local d_2R "$\infty$"
    }
    else {
        local d_2R : di %9.2f delta_2R[`i']
    }

    local ba_13 : di %9.3f beta_adj_13[`i']
    local ba_2R : di %9.3f beta_adj_2R[`i']

    ** For earnings, use different formatting
    if `i' == 4 {
        local b_R : di %9.1f beta_R[`i']
        local b_F : di %9.1f beta_F[`i']
        local ba_13 : di %9.1f beta_adj_13[`i']
        local ba_2R : di %9.1f beta_adj_2R[`i']
    }

    local out_name = outcome[`i']
    replace str_line = ///
        "`out_name' & `b_R' & `b_F' & `r_R' & `r_F' & `d_13' & `ba_13' & `d_2R' & `ba_2R' \\" ///
        in `i'
}

** Write to file
local outfile "${results}tables/tab_oster_bounds.tex"

** Open file handle
tempname fh
file open `fh' using "`outfile'", write replace

** Write rows
forvalues i = 1/4 {
    local line = str_line[`i']
    file write `fh' "`line'" _n
    if `i' == 3 {
        file write `fh' "\midrule" _n
    }
}

file close `fh'

di _n "Oster bounds table exported: tab_oster_bounds.tex"

** Also export to Overleaf if enabled
if ${overleaf} == 1 {
    copy "`outfile'" "${ol_tab}tab_oster_bounds.tex", replace
}

restore

** =============================================================================
** Try psacalc if available (supplementary check)
** =============================================================================

** psacalc requires the controlled regression to be in memory
** Try it for part-time (our most robust outcome) as a cross-check
capture which psacalc
if _rc == 0 {
    di _n "=== psacalc cross-check (part-time employment) ==="

    ** Run the full model first (psacalc uses the last regression)
    qui reghdfe part_time_y treated $controls c.$unemp#i.qc_ct c.$minwage#i.qc_ct [aw=weight], ///
        absorb($did_base) vce(cluster $clustervar)

    ** Try psacalc with Rmax = 1.3x
    capture noisily psacalc treated, rmax(`= min(1.3 * e(r2), 1)') delta(1)

    if _rc != 0 {
        di "  psacalc failed (likely incompatible with reghdfe absorbed FEs)"
        di "  Manual computation above is the primary result"
    }
}
else {
    di _n "psacalc not installed — using manual Oster formula only"
    di "  To install: ssc install psacalc"
}

** =============================================================================
** End
** =============================================================================

clear
log close log_03_tab_oster_bounds
