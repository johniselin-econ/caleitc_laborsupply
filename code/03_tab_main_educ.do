/*******************************************************************************
File Name:      03_tab_main_educ.do
Creator:        John Iselin (reconstructed July 2026)
Date Update:    July 2026

Purpose:        RECONSTRUCTION of the missing script behind the committed
                outputs tab_main_educ_{1,2,3}.tex, tab_main_educ_end.tex,
                fig_event_emp_educ_coefficients.csv, and fig_event_emp_educ.*
                (added in commit 53a2fed with no producing do-file).

                Inferred design — WITHIN-CALIFORNIA triple-difference using
                education (non-college vs. college) in place of the state
                dimension:

                    treated = noncollege x qc_present x post,  CA only

                Column structure (from tab_main_educ_end.tex):
                  (1) Triple-Difference FEs
                  (2) + County FEs
                  (3) + Demographic Controls

                VALIDATION TARGETS (committed outputs; confirm before trusting):
                  N = 132,910 in all columns
                  Employed:  ATE 1.8* (0.9) | 1.7* (0.9) | 1.5 (1.0),  ymean 71.6
                  Full-time: ATE 1.1 (1.2)  | 1.0 (1.2)  | 0.7 (1.2),  ymean 51.3
                  Part-time: ATE 0.7 (0.9)  | 0.7 (0.8)  | 0.8 (0.9),  ymean 20.4
                  Event study (col-3 controls), e.g. employed 2016 = 2.887 (1.124)

                Open reconstruction choices (flagged, not certain):
                  - SEs clustered on county_fips (state clustering is impossible
                    within CA; committed SE magnitudes are consistent with
                    county clustering). ACS-unidentified counties (county_fips
                    == 0) form a single cluster.
                  - Demographic controls exclude education (it is the third
                    difference dimension here).

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_tab_main_educ
log using "${logs}03_tab_main_educ_log_${date}", ///
    name(log_03_tab_main_educ) replace text

** =============================================================================
** Load data and prepare sample: California only, ALL education levels
** =============================================================================

use if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        state_fips == 6 & ///
        inrange(year, ${start_year}, ${end_year}) ///
    using "${data}final/acs_working_file.dta", clear

** Define outcomes
local outcomes "employed_y full_time_y part_time_y"

** Rescale outcome variables to percentage points
foreach out of local outcomes {
    replace `out' = `out' * 100
}

** Education dimension (replaces the state dimension of the main design)
gen noncollege = (education < 4)
label var noncollege "No college degree"

** DID variables
gen post = (year >= 2015)
gen treated = (noncollege == 1 & qc_present == 1 & post == 1)
label var treated "ATE"

** Constant "state" indicator for add_table_stats (all obs are CA)
gen ca = 1

** Event-study interaction (repo convention, cf. setup_did_vars)
gen childXyearXeduc = cond(qc_present == 1 & noncollege == 1, year, 2014)

** Update adults per HH (cap at 3)
replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

** =============================================================================
** Define specifications
** =============================================================================

** Demographic controls: standard set minus education (3rd diff dimension)
local demog "age_bracket minage_qc race_group hispanic hh_adult_ct"

** SPEC 1: Triple-difference FEs (education x year x QC pairwise structure)
local fes1 "noncollege year qc_ct noncollege#year noncollege#qc_ct year#qc_ct"
local controls1 ""

** SPEC 2: Add county FEs
local fes2 "`fes1' county_fips"
local controls2 ""

** SPEC 3: Add demographic controls
local fes3 "`fes2'"
local controls3 "`demog'"

** Clustering (see header note)
local cl "county_fips"

** =============================================================================
** Run regressions and export tables
** =============================================================================

eststo clear

local ct = 1

foreach out of local outcomes {

    forvalues spec = 1(1)3 {

        eststo est_educ_`out'_`spec': ///
            reghdfe `out' treated [aw = weight], ///
            absorb(`fes`spec'' `controls`spec'') ///
            vce(cluster `cl')

        ** Add ymean and implied effect (mirrors add_table_stats usage)
        add_table_stats, ///
            outcome(`out') treatvar(treated) postvar(post) ///
            statevar(ca) qcvar(qc_present) weightvar(weight) ///
            samplecond("noncollege == 1")

        ** Spec indicator strings
        local s2txt = cond(`spec' >= 2, "Yes", "No")
        local s3txt = cond(`spec' >= 3, "Yes", "No")
        estadd local s1 "Yes"
        estadd local s2 "`s2txt'"
        estadd local s3 "`s3txt'"
    }

    ** Export panel using utility (dual local/Overleaf export)
    export_results est_educ_`out'_1 est_educ_`out'_2 est_educ_`out'_3, ///
        filename("tab_main_educ_`ct'.tex") ///
        statslist($stats_list) ///
        statsfmt($stats_fmt) ///
        label1("  Observations") ///
        label2("  Adj. R-Square") ///
        label3("  Treated group mean in pre-period") ///
        label4("  Implied employment effect")

    ** Spec indicators footer (first outcome only)
    if `ct' == 1 {
        export_results est_educ_`out'_1 est_educ_`out'_2 est_educ_`out'_3, ///
            filename("tab_main_educ_end.tex") ///
            statslist("s1 s2 s3") ///
            statsfmt("%9s %9s %9s") ///
            label1("  Triple-Difference FEs") ///
            label2("  County FEs") ///
            label3("  Demographic Controls") ///
            cellsnone
    }

    local ct = `ct' + 1
}

** =============================================================================
** Event study (spec 3 controls) + coefficient CSV + figure
** =============================================================================

tempname coefs
postfile `coefs' str20 outcome year coef se ci_lo ci_hi ///
    using "${data}tmp/educ_event_coefs.dta", replace

foreach out of local outcomes {

    eststo ev_educ_`out': ///
        reghdfe `out' ib2014.childXyearXeduc [aw = weight], ///
        absorb(`fes3' `controls3') ///
        vce(cluster `cl')

    forvalues y = ${start_year}(1)${end_year} {
        if `y' == 2014 continue
        local b = _b[`y'.childXyearXeduc]
        local s = _se[`y'.childXyearXeduc]
        post `coefs' ("`out'") (`y') (`b') (`s') ///
            (`b' - 1.96 * `s') (`b' + 1.96 * `s')
    }
}

postclose `coefs'

** Export coefficients to CSV (matches committed
** fig_event_emp_educ_coefficients.csv format)
preserve
use "${data}tmp/educ_event_coefs.dta", clear
export delimited using ///
    "${results}tables/fig_event_emp_educ_coefficients.csv", replace
restore

** Event-study figure
coefplot ///
    (ev_educ_employed_y, label("Employed") msymbol(O)) ///
    (ev_educ_full_time_y, label("Full-time") msymbol(D)) ///
    (ev_educ_part_time_y, label("Part-time") msymbol(T)), ///
    keep(*.childXyearXeduc) vertical ///
    rename(^([0-9]+)\.childXyearXeduc$ = \1, regex) ///
    yline(0, lcolor(gs8) lpattern(dash)) ///
    xline(2.5, lcolor(gs8)) ///
    ciopts(recast(rcap)) ///
    ytitle("Effect on employment (pp), non-college vs. college") ///
    xtitle("Year") ///
    note("Within-California triple-difference by education. Base year: 2014.")

export_graph, filename("fig_event_emp_educ")

** =============================================================================
** End
** =============================================================================

clear
log close log_03_tab_main_educ
