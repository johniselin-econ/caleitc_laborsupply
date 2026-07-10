/*******************************************************************************
File Name:      utils/programs.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Define reusable Stata programs for CalEITC analysis
                - qc_assignment: Qualifying children assignment
                - run_triple_diff: Triple-difference regression
                - run_event_study: Event study regression
                - export_reg_table: Export regression results to LaTeX
                - make_coefplot: Create coefficient plots

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** =============================================================================
** PROGRAM 1: qc_assignment
** Assigns qualifying children to potential adults in household
** Based on parent-child relationships from IPUMS variables
** =============================================================================

capture program drop qc_assignment
program define qc_assignment

    ** Confirm required variables exist
    foreach var of varlist pernum qc age hh_id ///
                          hoh sibling foster grandchild ///
                          momloc momloc2 poploc poploc2 sploc {
        capture describe `var'
        assert _rc == 0
    }

    ** Variables to be created
    local varlist "qc_ct matched min_qc_age"

    ** Confirm variables do not exist
    foreach var of local varlist {
        capture describe `var'
        assert _rc != 0
    }

    ** Make sure household id and person number is unique id and sort
    gisid hh_id pernum
    gsort hh_id pernum

    ** Adjust age < 1 to be 1
    replace age = 1 if age == 0

    ** Count max number of people per household
    gegen max_hh_pernum = max(pernum), by(hh_id)

    ** Check if there are any QC in a household
    gegen any_qc = max(qc), by(hh_id)

    ** Generate empty values for count of QC
    gen qc_ct = 0
    gen matched = 0
    gen min_qc_age = .
    qui summ pernum
    local maxpernum = `r(max)'

    ** Loop over person number
    forvalues i = 1(1)`maxpernum' {

        dis "Processing person `i'"

        ** Create temporary file
        tempfile pre_loop
        save `pre_loop'

        ** Keep only if household has person i
        keep if max_hh_pernum >= `i'

        ** Keep only if household has at least one QC
        keep if any_qc == 1

        ** Get age, QC for potential parent (i)
        gen age_tmp = age if pernum == `i'
        gen qc_tmp = qc if pernum == `i'

        ** Assign those variables to all potential QC (j)
        gegen pernum_age = mean(age_tmp), by(hh_id)
        gegen pernum_qc = mean(qc_tmp), by(hh_id)

        drop age_tmp qc_tmp

        ** Generate indicator:
        ** - Person i is parent of person j AND
        ** - Person i is older than person j AND
        ** - Person j is a QC AND
        ** - Person i is not a QC
        gen tmp1 = ((`i' == momloc) | (`i' == momloc2) | ///
                    (`i' == poploc) | (`i' == poploc2)) & ///
                   (age < pernum_age) & ///
                   (qc == 1) & ///
                   (pernum_qc == 0)

        ** Across all of person i's QC, get minimum age
        gen tmp_age = age if tmp1 == 1
        gegen min_age = min(tmp_age), by(hh_id)

        ** Update matched count
        qui replace matched = matched + tmp1

        ** Count QC assigned to person i
        gegen tmp2 = total(tmp1), by(hh_id)

        ** Update person i's count of QC
        qui replace qc_ct = tmp2 if pernum == `i' & qc == 0

        ** Update person i's minimum age of QC
        qui replace min_qc_age = min_age if ///
            (pernum == `i') & (qc == 0)

        ** Keep required variables
        keep hh_id pernum qc_ct min_qc_age matched

        ** Save as temporary file
        tempfile post_loop_`i'
        save `post_loop_`i''
        clear

        ** Load tempfile
        use `pre_loop'

        ** Merge using stored data
        merge 1:1 hh_id pernum using `post_loop_`i'', nogen update replace

        ** Clear tempfiles
        rm `post_loop_`i''
        rm `pre_loop'

    }

    ** Cap QC count at 9
    replace qc_ct = 9 if qc_ct > 9

    ** For unassigned QC, assign based on relationship to householder
    ** Get HOH attributes
    gen age_tmp = age if hoh == 1
    gen qc_tmp = qc if hoh == 1

    gegen hoh_age = mean(age_tmp), by(hh_id)
    gegen hoh_qc = mean(qc_tmp), by(hh_id)

    drop age_tmp qc_tmp

    ** Loop over relationship types
    foreach var of varlist grandchild foster sibling {

        dis "Assigning QC by relationship: `var'"

        ** Generate indicator for unassigned QC of given relationship
        gen tmp = (qc == 1) & (`var' == 1) & (matched == 0) & ///
                  (age < hoh_age) & (hoh_qc == 0)

        gen tmp_age = age if tmp == 1

        ** Get total number of assigned QC
        by hh_id: gegen total_qc_`var' = total(tmp)

        ** Add to QC count for HOH
        replace qc_ct = qc_ct + total_qc_`var' if hoh == 1 & qc == 0

        ** Update minimum age
        gegen min_age = min(tmp_age), by(hh_id)
        replace min_qc_age = min_age if ///
            (hoh == 1) & (qc == 0) & ///
            (missing(min_qc_age) | min_qc_age > min_age)

        ** Update matched tag
        replace matched = 1 if tmp == 1

        ** Drop variables
        drop tmp total_qc_`var' min_age tmp_age

    }

    ** Clean up
    drop hoh_age hoh_qc max_hh_pernum any_qc

end


** =============================================================================
** PROGRAM 2: run_triple_diff
** Runs triple-difference regression with specified controls and FEs
** =============================================================================

capture program drop run_triple_diff
program define run_triple_diff, rclass

    syntax varlist(min=1 max=1) [if], ///
        TREATvar(varname)        ///
        [CONTROLs(varlist)]      ///
        [UNEMPvar(varname)]      ///
        [MINWAGEvar(varname)]    ///
        [FEs(string)]            ///
        [WEIGHTvar(varname)]     ///
        [CLUSTERvar(varname)]    ///
        [QCvar(varname)]

    ** Set outcome variable
    local outcome `varlist'

    ** Build regression command
    local regcmd "reghdfe `outcome' `treatvar'"

    ** Add unemployment control (interacted with QC)
    if "`unempvar'" != "" & "`qcvar'" != "" {
        local regcmd "`regcmd' c.`unempvar'#i.`qcvar'"
    }
    else if "`unempvar'" != "" {
        local regcmd "`regcmd' `unempvar'"
    }

    ** Add minimum wage control (interacted with QC)
    if "`minwagevar'" != "" & "`qcvar'" != "" {
        local regcmd "`regcmd' c.`minwagevar'#i.`qcvar'"
    }
    else if "`minwagevar'" != "" {
        local regcmd "`regcmd' `minwagevar'"
    }

    ** Add if condition
    if "`if'" != "" {
        local regcmd "`regcmd' `if'"
    }

    ** Add weights
    if "`weightvar'" != "" {
        local regcmd "`regcmd' [aw = `weightvar']"
    }

    ** Add fixed effects and controls as absorb
    if "`fes'" != "" | "`controls'" != "" {
        local absorb_list ""
        if "`fes'" != "" local absorb_list "`fes'"
        if "`controls'" != "" local absorb_list "`absorb_list' `controls'"
        local regcmd "`regcmd', absorb(`absorb_list')"
    }

    ** Add clustering
    if "`clustervar'" != "" {
        local regcmd "`regcmd' vce(cluster `clustervar')"
    }

    ** Run regression
    di "`regcmd'"
    `regcmd'

    ** Return results
    return scalar b = _b[`treatvar']
    return scalar se = _se[`treatvar']
    return scalar N = e(N)
    return scalar r2_a = e(r2_a)

end


** =============================================================================
** PROGRAM 3: run_event_study
** Runs event study regression with year interactions
** =============================================================================

capture program drop run_event_study
program define run_event_study, rclass

    syntax varlist(min=1 max=1), ///
        EVENTvar(varname)        /// Variable for year X treatment interaction
        BASEyear(integer)        /// Base year for comparison
        [CONTROLs(varlist)]      ///
        [UNEMPvar(varname)]      ///
        [MINWAGEvar(varname)]    ///
        [FEs(string)]            ///
        [WEIGHTvar(varname)]     ///
        [CLUSTERvar(varname)]    ///
        [QCvar(varname)]

    ** Set outcome variable
    local outcome `varlist'

    ** Build regression command
    local regcmd "reghdfe `outcome' b`baseyear'.`eventvar'"

    ** Add unemployment control (interacted with QC)
    if "`unempvar'" != "" & "`qcvar'" != "" {
        local regcmd "`regcmd' c.`unempvar'#i.`qcvar'"
    }

    ** Add minimum wage control (interacted with QC)
    if "`minwagevar'" != "" & "`qcvar'" != "" {
        local regcmd "`regcmd' c.`minwagevar'#i.`qcvar'"
    }

    ** Add weights
    if "`weightvar'" != "" {
        local regcmd "`regcmd' [aw = `weightvar']"
    }

    ** Add fixed effects and controls as absorb
    if "`fes'" != "" | "`controls'" != "" {
        local absorb_list ""
        if "`fes'" != "" local absorb_list "`fes'"
        if "`controls'" != "" local absorb_list "`absorb_list' `controls'"
        local regcmd "`regcmd', absorb(`absorb_list')"
    }

    ** Add clustering
    if "`clustervar'" != "" {
        local regcmd "`regcmd' vce(cluster `clustervar')"
    }

    ** Run regression
    di "`regcmd'"
    `regcmd'

end


** =============================================================================
** PROGRAM 4: make_event_plot
** Creates event study coefficient plot
**
** Labels are passed using | as separator to avoid quote handling issues
** e.g., labels(Employed|Employed full-time|Employed part-time)
** =============================================================================

capture program drop make_event_plot
program define make_event_plot

    syntax namelist(min=1 max=3), ///
        EVENTvar(varname)          ///
        STARTyear(integer)         ///
        ENDyear(integer)           ///
        [BASEyear(integer 2014)]   ///
        [YMAX(real 6)]             ///
        [YCUT(real 2)]             ///
        [SAVEpath(string)]         ///
        [Labels(string)]

    ** Generate coefficient labels
    local coef `""'
    local keep ""

    forvalues y = `startyear'(1)`endyear' {
        local keep "`keep' `y'.`eventvar'"
        local coef `"`coef' `y'.`eventvar' = "`y'""'
    }

    ** Set up xlines (line should appear AFTER base year, before treatment)
    local xline_val = `baseyear' - `startyear' + 1.5

    ** Parse model names and labels
    local nmodels : word count `namelist'

    ** Parse labels (| separated) into individual locals
    if "`labels'" == "" {
        ** Default labels if none provided
        forvalues i = 1/`nmodels' {
            local lbl`i' "Model `i'"
        }
    }
    else {
        ** Parse | separated labels using gettoken
        local lbl_remaining "`labels'"
        forvalues i = 1/`nmodels' {
            gettoken lbl`i' lbl_remaining : lbl_remaining, parse("|")
            if "`lbl`i''" == "|" {
                gettoken lbl`i' lbl_remaining : lbl_remaining, parse("|")
            }
        }
    }

    ** Build coefplot command (let scheme handle colors)
    local plotcmd "coefplot"
    local i = 1
    foreach m of local namelist {
        local plotcmd `"`plotcmd' (`m', label("`lbl`i''"))"'
        local i = `i' + 1
    }

    ** Add options (scheme-consistent formatting)
    local plotcmd `"`plotcmd', keep(`keep') coeflabels(`coef') msize(small)"'
    local plotcmd `"`plotcmd' ytitle("Average Treatment Effect (pp)")"'
    local plotcmd `"`plotcmd' xlabel(, labsize(small) angle(45))"'
    local plotcmd `"`plotcmd' xline(`xline_val', lcolor(gs6) lwidth(medium))"'
    local plotcmd `"`plotcmd' omitted baselevels"'
    local plotcmd `"`plotcmd' yline(0, lcolor(gs8) lpattern(dash))"'
    local plotcmd `"`plotcmd' vertical ciopts(recast(rcap))"'
    local plotcmd `"`plotcmd' legend(row(1) pos(6) size(small))"'
    local plotcmd `"`plotcmd' ylabel(-`ymax'(`ycut')`ymax', labsize(small))"'

    ** Execute
    `plotcmd'

    ** Save if path specified
    if "`savepath'" != "" {
        graph export "`savepath'", as(jpg) name("Graph") quality(100) replace
    }

end


** =============================================================================
** PROGRAM 5: get_pre_period_mean
** Calculates weighted mean for treated group in pre-period
** =============================================================================

capture program drop get_pre_period_mean
program define get_pre_period_mean, rclass

    syntax varlist(min=1 max=1), ///
        TREATstate(integer)      /// FIPS of treated state
        PREyear(integer)         /// Last year of pre-period
        QCvar(varname)           /// QC indicator
        [WEIGHTvar(varname)]     ///
        [YEARvar(varname)]       ///
        [STATEvar(varname)]

    local outcome `varlist'

    ** Set defaults
    if "`yearvar'" == "" local yearvar "year"
    if "`statevar'" == "" local statevar "statefip"

    ** Calculate mean
    if "`weightvar'" != "" {
        qui summ `outcome' if ///
            `yearvar' <= `preyear' & ///
            `statevar' == `treatstate' & ///
            `qcvar' == 1 ///
            [aweight = `weightvar']
    }
    else {
        qui summ `outcome' if ///
            `yearvar' <= `preyear' & ///
            `statevar' == `treatstate' & ///
            `qcvar' == 1
    }

    return scalar mean = `r(mean)'

end

** =============================================================================
** PROGRAM 6: run_ppml_event_study
** Runs PPML event study regression with year interactions
** =============================================================================

capture program drop run_ppml_event_study
program define run_ppml_event_study, rclass

    syntax varlist(min=1 max=1), ///
        EVENTvar(varname)        /// Variable for year X treatment interaction
        BASEyear(integer)        /// Base year for comparison
        [CONTROLs(varlist)]      ///
        [UNEMPvar(varname)]      ///
        [MINWAGEvar(varname)]    ///
        [FEs(string)]            ///
        [WEIGHTvar(varname)]     ///
        [CLUSTERvar(varname)]    ///
        [QCvar(varname)]         ///
        [SAMPLEcond(string)]

    ** Set outcome variable
    local outcome `varlist'

    ** Build regression command
    local regcmd "ppmlhdfe `outcome' b`baseyear'.`eventvar'"

    ** Add unemployment control (interacted with QC)
    if "`unempvar'" != "" & "`qcvar'" != "" {
        local regcmd "`regcmd' c.`unempvar'#i.`qcvar'"
    }

    ** Add minimum wage control (interacted with QC)
    if "`minwagevar'" != "" & "`qcvar'" != "" {
        local regcmd "`regcmd' c.`minwagevar'#i.`qcvar'"
    }

    ** Add sample condition
    if "`samplecond'" != "" {
        local regcmd "`regcmd' if `samplecond'"
    }

    ** Add weights (PPML uses pw)
    if "`weightvar'" != "" {
        local regcmd "`regcmd' [pw = `weightvar']"
    }

    ** Add fixed effects and controls as absorb
    if "`fes'" != "" | "`controls'" != "" {
        local absorb_list ""
        if "`fes'" != "" local absorb_list "`fes'"
        if "`controls'" != "" local absorb_list "`absorb_list' `controls'"
        local regcmd "`regcmd', absorb(`absorb_list')"
    }

    ** Add clustering
    if "`clustervar'" != "" {
        local regcmd "`regcmd' vce(cluster `clustervar')"
    }

    ** Run regression
    di "`regcmd'"
    `regcmd'

end


** =============================================================================
** PROGRAM 7: run_ppml_regression
** Runs PPML regression with margins for average marginal effect
** =============================================================================

capture program drop run_ppml_regression
program define run_ppml_regression, rclass

    syntax varlist(min=1 max=1), ///
        TREATvar(varname)        ///
        [CONTROLs(varlist)]      ///
        [UNEMPvar(varname)]      ///
        [MINWAGEvar(varname)]    ///
        [FEs(string)]            ///
        [WEIGHTvar(varname)]     ///
        [CLUSTERvar(varname)]    ///
        [QCvar(varname)]         ///
        [SAMPLEcond(string)]

    ** Set outcome variable
    local outcome `varlist'

    ** Build regression command
    local regcmd "ppmlhdfe `outcome' `treatvar'"

    ** Add unemployment control (interacted with QC)
    if "`unempvar'" != "" & "`qcvar'" != "" {
        local regcmd "`regcmd' c.`unempvar'#i.`qcvar'"
    }
    else if "`unempvar'" != "" {
        local regcmd "`regcmd' `unempvar'"
    }

    ** Add minimum wage control (interacted with QC)
    if "`minwagevar'" != "" & "`qcvar'" != "" {
        local regcmd "`regcmd' c.`minwagevar'#i.`qcvar'"
    }
    else if "`minwagevar'" != "" {
        local regcmd "`regcmd' `minwagevar'"
    }

    ** Add sample condition
    if "`samplecond'" != "" {
        local regcmd "`regcmd' if `samplecond'"
    }

    ** Add weights (PPML uses pw)
    if "`weightvar'" != "" {
        local regcmd "`regcmd' [pw = `weightvar']"
    }

    ** Add fixed effects and controls as absorb
    if "`fes'" != "" | "`controls'" != "" {
        local absorb_list ""
        if "`fes'" != "" local absorb_list "`fes'"
        if "`controls'" != "" local absorb_list "`absorb_list' `controls'"
        local regcmd "`regcmd', absorb(`absorb_list')"
    }

    ** Add clustering and d option for margins
    if "`clustervar'" != "" {
        local regcmd "`regcmd' vce(cluster `clustervar') d"
    }
    else {
        local regcmd "`regcmd' d"
    }

    ** Run regression
    di "`regcmd'"
    `regcmd'

    ** Store coefficient
    local b = _b[`treatvar']
    local se = _se[`treatvar']

    ** Run margins for average marginal effect
    margins, dydx(`treatvar') noestimcheck
    local ame = el(r(b),1,1)

    ** Return results
    return scalar b = `b'
    return scalar se = `se'
    return scalar N = e(N)
    return scalar r2_p = e(r2_p)
    return scalar AME = `ame'

end


** =============================================================================
** PROGRAM 8: export_table_panel
** Exports a panel of regression results to LaTeX
**
** Labels are passed using | as separator to avoid quote handling issues
** e.g., statslabels(Observations|Adj R-Square|Mean|Effect)
** Note: Avoid periods in labels as they can cause Stata parsing issues
** =============================================================================

capture program drop export_table_panel
program define export_table_panel

    syntax namelist(min=1), ///
        OUTfile(string)              /// Output file path
        [STATSlist(string)]          /// Statistics to include
        [STATSfmt(string)]           /// Statistics formats
        [STATSlabels(string)]        /// Statistics labels (| separated)
        [BDIGITS(integer 1)]         /// Decimal places for coefficients
        [SEDIGITS(integer 1)]        /// Decimal places for SEs
        [KEEPvars(string)]           /// Variables to keep in output
        [ORDERvars(string)]          ///
        [PREHEAD(string)]

    ** Set defaults
    if "`statslist'" == "" local statslist "N r2_a"
    if "`statsfmt'" == "" local statsfmt "%9.0fc %9.3fc"
    if "`keepvars'" == "" local keepvars "treated"
    if "`ordervars'" == "" local ordervars "treated"
    if "`prehead'" == "" local prehead "\\ \midrule"

    ** Parse stats labels (| separated) into individual locals
    if "`statslabels'" != "" {
        tokenize "`statslabels'", parse("|")
        local lbl_ct = 0
        local i = 1
        while "``i''" != "" {
            if "``i''" != "|" {
                local ++lbl_ct
                local lbl`lbl_ct' "``i''"
            }
            local ++i
        }

        ** Build the labels option based on count
        if `lbl_ct' == 1 {
            local lbl_opt `"labels("`lbl1'")"'
        }
        else if `lbl_ct' == 2 {
            local lbl_opt `"labels("`lbl1'" "`lbl2'")"'
        }
        else if `lbl_ct' == 3 {
            local lbl_opt `"labels("`lbl1'" "`lbl2'" "`lbl3'")"'
        }
        else if `lbl_ct' == 4 {
            local lbl_opt `"labels("`lbl1'" "`lbl2'" "`lbl3'" "`lbl4'")"'
        }
        else if `lbl_ct' == 5 {
            local lbl_opt `"labels("`lbl1'" "`lbl2'" "`lbl3'" "`lbl4'" "`lbl5'")"'
        }
        else {
            local lbl_opt ""
        }
    }
    else {
        local lbl_opt ""
    }

    ** Build and run esttab command
    if "`lbl_opt'" != "" {
        esttab `namelist' using "`outfile'", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
            stats(`statslist', fmt(`statsfmt') `lbl_opt') ///
            b(`bdigits') se(`sedigits') label order(`ordervars') keep(`keepvars') ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("`prehead'")
    }
    else {
        esttab `namelist' using "`outfile'", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
            stats(`statslist', fmt(`statsfmt')) ///
            b(`bdigits') se(`sedigits') label order(`ordervars') keep(`keepvars') ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("`prehead'")
    }

end


** =============================================================================
** PROGRAM 9: add_spec_indicators
** Adds specification indicator statistics (s1-s4) to stored estimates
** =============================================================================

capture program drop add_spec_indicators
program define add_spec_indicators

    syntax, SPEC(integer)

    ** Add specification indicators based on spec number
    if `spec' == 1 {
        estadd local s1 "Yes"
        estadd local s2 "No"
        estadd local s3 "No"
        estadd local s4 "No"
    }
    else if `spec' == 2 {
        estadd local s1 "Yes"
        estadd local s2 "Yes"
        estadd local s3 "No"
        estadd local s4 "No"
    }
    else if `spec' == 3 {
        estadd local s1 "Yes"
        estadd local s2 "Yes"
        estadd local s3 "Yes"
        estadd local s4 "No"
    }
    else if `spec' == 4 {
        estadd local s1 "Yes"
        estadd local s2 "Yes"
        estadd local s3 "Yes"
        estadd local s4 "Yes"
    }

end


** =============================================================================
** PROGRAM 10: add_table_stats
** Adds common table statistics (ymean, implied effect) to stored estimates
** =============================================================================

capture program drop add_table_stats
program define add_table_stats

    syntax, ///
        OUTcome(varname)         /// Outcome variable
        TREATvar(varname)        /// Treatment variable
        POSTvar(varname)         /// Post-period indicator
        STATEvar(varname)        /// State indicator (CA=1)
        QCvar(varname)           /// QC presence indicator
        [WEIGHTvar(varname)]     /// Weight variable
        [SAMPLEcond(string)]     /// Additional sample condition

    ** Get coefficient
    local beta = _b[`treatvar']

    ** Build sample condition for pre-period mean
    local cond "`postvar' == 0 & `statevar' == 1 & `qcvar' == 1"
    if "`samplecond'" != "" {
        local cond "`cond' & `samplecond'"
    }

    ** Get pre-period treated mean
    if "`weightvar'" != "" {
        qui summ `outcome' if `cond' [aweight = `weightvar']
    }
    else {
        qui summ `outcome' if `cond'
    }
    local mean = r(mean)
    estadd scalar ymean = `mean'

    ** Calculate implied employment effect
    local treat_cond "`treatvar' == 1"
    if "`samplecond'" != "" {
        local treat_cond "`treat_cond' & `samplecond'"
    }

    if "`weightvar'" != "" {
        qui summ `outcome' if `treat_cond' [fw = `weightvar']
    }
    else {
        qui summ `outcome' if `treat_cond'
    }
    local C_tmp = r(N) * `beta' / 100
    estadd scalar C = `C_tmp'

end


** =============================================================================
** PROGRAM 11: export_spec_indicators
** Exports specification indicators table (used at end of multi-panel tables)
** =============================================================================

capture program drop export_spec_indicators
program define export_spec_indicators

    syntax namelist(min=1), OUTfile(string)

    local stats_list "s1 s2 s3 s4"
    local stats_fmt "%9s %9s %9s %9s"
    local stats_labels `" "Triple-Difference" "Add Demographic Controls" "Add Unemployment Controls" "Add Minimum Wage Controls" "'

    esttab `namelist' using "`outfile'", ///
        booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
        stats(`stats_list', ///
            fmt(`stats_fmt') ///
            labels(`stats_labels')) ///
        cells(none) prehead("\\ \midrule")

end


** =============================================================================
** PROGRAM 12: make_table_coefplot
** Creates coefficient plot from table estimates (multiple outcomes x specs)
** Produces a figure like Table 2 visualization with panels by outcome
**
** Labels are passed using | as separator to avoid quote handling issues
** e.g., speclabels(No Controls|Individual Controls|Add Unemployment|Add Min Wage)
** =============================================================================

capture program drop make_table_coefplot
program define make_table_coefplot

    syntax, ///
        OUTcomes(string)         /// Space-separated list of outcome names
        OUTlabels(string)        /// Labels for outcomes (| separated)
        SPECprefix(string)       /// Estimate name prefix (e.g., "est_")
        NUMspecs(integer)        /// Number of specifications per outcome
        [SPEClabels(string)]     /// Labels for specifications (| separated)
        [COEFvar(string)]        /// Coefficient variable to plot (default: treated)
        [YTITle(string)]         /// Y-axis title
        [YMIN(real -6)]          /// Y-axis minimum
        [YMAX(real 6)]           /// Y-axis maximum
        [YCUT(real 2.5)]         /// Y-axis tick interval
        [SAVEpath(string)]       /// Output file path

    ** Set defaults
    if "`coefvar'" == "" local coefvar "treated"
    if "`ytitle'" == "" local ytitle "Effect (pp)"

    ** Default spec labels if not provided
    if "`speclabels'" == "" {
        local speclabels "No Controls|Individual Controls|Add Unemployment|Add Minimum Wage"
    }

    ** Parse specification labels (| separated)
    local spec_remaining "`speclabels'"
    forvalues s = 1/`numspecs' {
        gettoken slbl`s' spec_remaining : spec_remaining, parse("|")
        if "`slbl`s''" == "|" {
            gettoken slbl`s' spec_remaining : spec_remaining, parse("|")
        }
    }

    ** Parse outcome labels (| separated) and build bylabels string
    local out_remaining "`outlabels'"
    local nout : word count `outcomes'
    local bylbl_str ""
    forvalues o = 1/`nout' {
        gettoken olbl out_remaining : out_remaining, parse("|")
        if "`olbl'" == "|" {
            gettoken olbl out_remaining : out_remaining, parse("|")
        }
        if `o' == 1 {
            local bylbl_str `""`olbl'""'
        }
        else {
            local bylbl_str `"`bylbl_str' "`olbl'""'
        }
    }

    ** Define markers for specifications (let scheme handle colors)
    local msym1 "O"
    local msym2 "S"
    local msym3 "T"
    local msym4 "D"

    ** Build the coefplot command dynamically
    ** Structure: (spec1_out1) (spec2_out1) ... || (spec1_out2) ...

    local plotcmd "coefplot"
    local out_ct = 0

    foreach out of local outcomes {
        local ++out_ct

        ** Add panel separator after first outcome
        if `out_ct' > 1 {
            local plotcmd "`plotcmd' ||"
        }

        ** Add each specification for this outcome
        forvalues s = 1/`numspecs' {

            ** Get spec label (only for first outcome to avoid legend duplication)
            if `out_ct' == 1 {
                local lbl_opt `"label("`slbl`s''")"'
            }
            else {
                local lbl_opt ""
            }

            ** Build estimate name
            local estname "`specprefix'`out'_`s'"

            ** Add to command (let scheme handle colors via pstyle)
            local plotcmd `"`plotcmd' (`estname', `lbl_opt' msymbol(`msym`s'') pstyle(p`s'))"'
        }
    }

    ** Build ylabel string
    local ylab_str "`ymin'(`ycut')`ymax'"

    ** Add coefplot options (scheme-consistent formatting)
    local plotcmd `"`plotcmd', keep(`coefvar')"'
    local plotcmd `"`plotcmd' ytitle("`ytitle'") msize(small)"'
    local plotcmd `"`plotcmd' yline(0, lcolor(gs8) lpattern(dash))"'
    local plotcmd `"`plotcmd' ylabel(`ylab_str', labsize(small))"'
    local plotcmd `"`plotcmd' vertical"'
    local plotcmd `"`plotcmd' ciopts(recast(rcap))"'
    local plotcmd `"`plotcmd' legend(rows(1) pos(6) size(small))"'
    local plotcmd `"`plotcmd' bylabels(`bylbl_str')"'
    local plotcmd `"`plotcmd' byopts(rows(1) imargin(small) note(""))"'
    local plotcmd `"`plotcmd' xlab(none)"'

    ** Display command for debugging
    di `"`plotcmd'"'

    ** Execute the command
    `plotcmd'

    ** Save if path specified
    if "`savepath'" != "" {
        graph export "`savepath'", as(png) name("Graph") width(2400) height(1200) replace
    }

end


** =============================================================================
** PROGRAM 13: load_baseline_sample
** Loads ACS data with standard sample restrictions
** =============================================================================

capture program drop load_baseline_sample
program define load_baseline_sample

    syntax, ///
        [VARlist(string)]        /// Additional variables to load
        [STARTyear(integer 0)]   /// Start year (default: use global)
        [ENDyear(integer 0)]     /// End year (default: use global)
        [SAMPLEcond(string)]     /// Additional sample conditions
        [NOQCvars]               /// Omit qc_* variables

    ** Set year defaults from globals if not specified
    if `startyear' == 0 local startyear = ${start_year}
    if `endyear' == 0 local endyear = ${end_year}

    ** Build variable list
    local base_vars "weight $outcomes $controls $unemp $minwage year"
    local base_vars "`base_vars' $baseline_vars"

    ** Add QC variables unless omitted
    if "`noqcvars'" == "" {
        local base_vars "`base_vars' qc_*"
    }

    ** Add any additional variables
    if "`varlist'" != "" {
        local base_vars "`base_vars' `varlist'"
    }

    ** Build sample condition
    local samp_cond "$baseline_sample & inrange(year, `startyear', `endyear')"

    ** Add additional conditions if specified
    if "`samplecond'" != "" {
        local samp_cond "`samp_cond' & `samplecond'"
    }

    ** Load data
    use `base_vars' if `samp_cond' using "${data}final/acs_working_file.dta", clear

    di _n "Loaded baseline sample: `startyear'-`endyear'"
    di "  N = " _N

end


** =============================================================================
** PROGRAM 14: setup_did_vars
** Creates standard DID variables (ca, post, treated) and caps hh_adult_ct
** =============================================================================

capture program drop setup_did_vars
program define setup_did_vars

    syntax, ///
        [TREATlabel(string)]     /// Label for treated variable (default: "ATE")
        [EVENTstudy]             /// Also create event study variable
        [POSTyear(integer 2014)] /// Year after which post=1 (default: 2014)

    ** Set default label
    if "`treatlabel'" == "" local treatlabel "ATE"

    ** Create California indicator
    capture drop ca
    gen ca = (state_fips == 6)

    ** Create post-period indicator
    capture drop post
    gen post = (year > `postyear')

    ** Create treatment indicator
    capture drop treated
    gen treated = (qc_present == 1 & ca == 1 & post == 1)
    label var treated "`treatlabel'"

    ** Create event study variable if requested
    if "`eventstudy'" != "" {
        capture drop childXyearXca
        gen childXyearXca = cond(qc_present == 1 & ca == 1, year, `postyear')
    }

    ** Cap adults per HH at 3 and label
    replace hh_adult_ct = 3 if hh_adult_ct > 3
    capture label drop lb_adult_ct
    label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
    label values hh_adult_ct lb_adult_ct

    di "DID variables created (post year = `postyear')"

end


** =============================================================================
** PROGRAM 15: export_results
** Exports table to local and Overleaf (if enabled) with single call
** =============================================================================

capture program drop export_results
program define export_results

    syntax namelist(min=1), ///
        FILEname(string)             /// Base filename (without path)
        [STATSlist(string)]          /// Statistics to include
        [STATSfmt(string)]           /// Statistics formats
        [STATSlabels(string)]        /// Labels: pipe-delimited (e.g., "Obs|R2|Mean")
        [LABEL1(string)]             /// Label for stat 1 (alternative to statslabels)
        [LABEL2(string)]             /// Label for stat 2
        [LABEL3(string)]             /// Label for stat 3
        [LABEL4(string)]             /// Label for stat 4
        [KEEPvars(string)]           /// Variables to keep
        [ORDERvars(string)]          /// Variable order
        [BDIGITS(integer 1)]         /// Decimal places for coefficients
        [SEDIGITS(integer 1)]        /// Decimal places for SEs
        [PREHEAD(string)]            /// Prehead option
        [CELLSnone]                  /// Use cells(none) for indicator tables
        [SUBfolder(string)]          /// Subfolder (tables or figures)

    ** Set defaults
    if "`statslist'" == "" local statslist "N r2_a ymean C"
    if "`statsfmt'" == "" local statsfmt "%9.0fc %9.3fc %9.1fc %9.0fc"
    if "`keepvars'" == "" local keepvars "treated"
    if "`ordervars'" == "" local ordervars "treated"
    if "`prehead'" == "" local prehead "\\ \midrule"
    if "`subfolder'" == "" local subfolder "tables"

    ** Build cells option
    if "`cellsnone'" != "" {
        local cells_opt "cells(none)"
    }
    else {
        local cells_opt "b(`bdigits') se(`sedigits')"
    }

    ** Build labels - check for individual label options first
    local has_labels = 0
    if "`label1'" != "" | "`label2'" != "" | "`label3'" != "" | "`label4'" != "" {
        local has_labels = 1
    }

    ** If statslabels provided (pipe-delimited), parse it
    if "`statslabels'" != "" & `has_labels' == 0 {
        local has_labels = 1
        ** Parse pipe-delimited labels
        local nlabels : word count `statslist'
        tokenize "`statslabels'", parse("|")
        local label1 "`1'"
        local label2 "`3'"
        local label3 "`5'"
        local label4 "`7'"
    }

    ** Build the labels string for esttab
    if `has_labels' {
        local labels_str ""
        if "`label1'" != "" local labels_str `""`label1'""'
        if "`label2'" != "" local labels_str `"`labels_str' "`label2'""'
        if "`label3'" != "" local labels_str `"`labels_str' "`label3'""'
        if "`label4'" != "" local labels_str `"`labels_str' "`label4'""'
    }

    ** Export to local results folder
    if `has_labels' {
        quietly esttab `namelist' using "${results}`subfolder'/`filename'", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
            stats(`statslist', fmt(`statsfmt') labels(`labels_str')) ///
            `cells_opt' label order(`ordervars') keep(`keepvars', relax) ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("`prehead'")
    }
    else {
        quietly esttab `namelist' using "${results}`subfolder'/`filename'", ///
            booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
            stats(`statslist', fmt(`statsfmt')) ///
            `cells_opt' label order(`ordervars') keep(`keepvars', relax) ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            prehead("`prehead'")
    }

    ** Export to Overleaf if enabled
    if ${overleaf} == 1 {
        if `has_labels' {
            quietly esttab `namelist' using "${ol_tab}`filename'", ///
                booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
                stats(`statslist', fmt(`statsfmt') labels(`labels_str')) ///
                `cells_opt' label order(`ordervars') keep(`keepvars', relax) ///
                star(* 0.10 ** 0.05 *** 0.01) ///
                prehead("`prehead'")
        }
        else {
            quietly esttab `namelist' using "${ol_tab}`filename'", ///
                booktabs fragment nobaselevels replace nomtitles nonumbers nolines ///
                stats(`statslist', fmt(`statsfmt')) ///
                `cells_opt' label order(`ordervars') keep(`keepvars', relax) ///
                star(* 0.10 ** 0.05 *** 0.01) ///
                prehead("`prehead'")
        }
    }

    di "Table exported: `filename'"

end


** =============================================================================
** PROGRAM 16: run_all_specs
** Runs all 4 specifications for a given outcome
** =============================================================================

capture program drop run_all_specs
program define run_all_specs

    syntax varlist(min=1 max=1), ///
        ESTprefix(string)            /// Prefix for stored estimates
        TREATvar(varname)            /// Treatment variable
        [CONTROLs(varlist)]          /// Demographic controls
        [UNEMPvar(varname)]          /// Unemployment variable
        [MINWAGEvar(varname)]        /// Minimum wage variable
        [FEs(string)]                /// Fixed effects
        [WEIGHTvar(varname)]         /// Weight variable
        [CLUSTERvar(varname)]        /// Cluster variable
        [QCvar(varname)]             /// QC count variable for interactions
        [POSTvar(varname)]           /// Post-period indicator
        [STATEvar(varname)]          /// State indicator
        [QCpresvar(varname)]         /// QC presence indicator
        [SAMPLEcond(string)]         /// Additional sample condition

    local outcome `varlist'

    ** Set defaults
    if "`postvar'" == "" local postvar "post"
    if "`statevar'" == "" local statevar "ca"
    if "`qcpresvar'" == "" local qcpresvar "qc_present"

    ** Build if condition
    local ifcond ""
    if "`samplecond'" != "" {
        local ifcond "if `samplecond'"
    }

    ** SPEC 1: Basic triple-diff FEs only
    eststo `estprefix'_1: ///
        run_triple_diff `outcome' `ifcond', ///
            treatvar(`treatvar') ///
            fes(`fes') ///
            weightvar(`weightvar') ///
            clustervar(`clustervar')

    add_table_stats, outcome(`outcome') treatvar(`treatvar') ///
        postvar(`postvar') statevar(`statevar') qcvar(`qcpresvar') ///
        weightvar(`weightvar') `samplecond_opt'
    add_spec_indicators, spec(1)

    ** SPEC 2: Add demographic controls
    eststo `estprefix'_2: ///
        run_triple_diff `outcome' `ifcond', ///
            treatvar(`treatvar') ///
            controls(`controls') ///
            fes(`fes') ///
            weightvar(`weightvar') ///
            clustervar(`clustervar')

    add_table_stats, outcome(`outcome') treatvar(`treatvar') ///
        postvar(`postvar') statevar(`statevar') qcvar(`qcpresvar') ///
        weightvar(`weightvar') `samplecond_opt'
    add_spec_indicators, spec(2)

    ** SPEC 3: Add unemployment controls
    eststo `estprefix'_3: ///
        run_triple_diff `outcome' `ifcond', ///
            treatvar(`treatvar') ///
            controls(`controls') ///
            unempvar(`unempvar') ///
            fes(`fes') ///
            weightvar(`weightvar') ///
            clustervar(`clustervar') ///
            qcvar(`qcvar')

    add_table_stats, outcome(`outcome') treatvar(`treatvar') ///
        postvar(`postvar') statevar(`statevar') qcvar(`qcpresvar') ///
        weightvar(`weightvar') `samplecond_opt'
    add_spec_indicators, spec(3)

    ** SPEC 4: Add minimum wage controls
    eststo `estprefix'_4: ///
        run_triple_diff `outcome' `ifcond', ///
            treatvar(`treatvar') ///
            controls(`controls') ///
            unempvar(`unempvar') ///
            minwagevar(`minwagevar') ///
            fes(`fes') ///
            weightvar(`weightvar') ///
            clustervar(`clustervar') ///
            qcvar(`qcvar')

    add_table_stats, outcome(`outcome') treatvar(`treatvar') ///
        postvar(`postvar') statevar(`statevar') qcvar(`qcpresvar') ///
        weightvar(`weightvar') `samplecond_opt'
    add_spec_indicators, spec(4)

end


** =============================================================================
** PROGRAM 17: export_event_coefficients
** Exports event study coefficients to CSV
** =============================================================================

capture program drop export_event_coefficients
program define export_event_coefficients

    syntax namelist(min=1), ///
        EVENTvar(varname)        /// Event study variable
        STARTyear(integer)       /// Start year
        ENDyear(integer)         /// End year
        BASEyear(integer)        /// Base year (omitted)
        OUTfile(string)          /// Output file path

    ** Store current data
    preserve

    ** Create empty dataset for coefficients
    clear
    gen outcome = ""
    gen year = .
    gen coef = .
    gen se = .
    gen ci_lo = .
    gen ci_hi = .

    local row = 1

    ** Loop over estimates and years
    foreach est of local namelist {
        ** Extract outcome name from estimate name (assumes est_OUTCOME format)
        local out = subinstr("`est'", "est_", "", 1)

        forvalues y = `startyear'(1)`endyear' {
            if `y' != `baseyear' {
                qui est restore `est'

                ** Get coefficient and SE
                local b = _b[`y'.`eventvar']
                local s = _se[`y'.`eventvar']

                ** Add row
                set obs `row'
                qui replace outcome = "`out'" in `row'
                qui replace year = `y' in `row'
                qui replace coef = `b' in `row'
                qui replace se = `s' in `row'
                qui replace ci_lo = `b' - 1.96 * `s' in `row'
                qui replace ci_hi = `b' + 1.96 * `s' in `row'

                local row = `row' + 1
            }
        }
    }

    ** Export
    export delimited "`outfile'", replace

    ** Restore original data
    restore

    di "Coefficients exported to: `outfile'"

end


** =============================================================================
** PROGRAM 18: export_graph
** Exports graph to local and Overleaf (if enabled)
** =============================================================================

capture program drop export_graph
program define export_graph

    syntax, ///
        FILEname(string)         /// Base filename (without extension)
        [FORMATlocal(string)]    /// Format for local (default: png)
        [FORMATol(string)]       /// Format for Overleaf (default: jpg)
        [WIDTH(integer 2400)]    /// Width in pixels
        [HEIGHT(integer 1600)]   /// Height in pixels
        [QUALITY(integer 100)]   /// JPG quality

    ** Set defaults
    if "`formatlocal'" == "" local formatlocal "png"
    if "`formatol'" == "" local formatol "jpg"

    ** Export to local results folder
    if "`formatlocal'" == "png" {
        graph export "${results}figures/`filename'.png", ///
            as(png) name("Graph") width(`width') height(`height') replace
    }
    else if "`formatlocal'" == "jpg" {
        graph export "${results}figures/`filename'.jpg", ///
            as(jpg) name("Graph") quality(`quality') replace
    }

    ** Also save alternate format locally
    if "`formatlocal'" == "png" {
        graph export "${results}figures/`filename'.jpg", ///
            as(jpg) name("Graph") quality(`quality') replace
    }

    ** Export to Overleaf if enabled
    if ${overleaf} == 1 {
        if "`formatol'" == "jpg" {
            graph export "${ol_fig}`filename'.jpg", ///
                as(jpg) quality(`quality') replace
        }
        else {
            graph export "${ol_fig}`filename'.png", ///
                as(png) width(`width') height(`height') replace
        }
    }

    di "Graph exported: `filename'"

end


** =============================================================================
** PROGRAM 19: run_heterogeneity_table
** Runs heterogeneity analysis across subgroups
** =============================================================================

capture program drop run_heterogeneity_table
program define run_heterogeneity_table

    syntax varlist(min=1 max=1), ///
        HETvar(varname)              /// Heterogeneity variable
        HETvals(numlist)             /// Values to loop over (0=all)
        ESTprefix(string)            /// Prefix for stored estimates
        TREATvar(varname)            /// Treatment variable
        [CONTROLs(varlist)]          /// Demographic controls
        [UNEMPvar(varname)]          /// Unemployment variable
        [MINWAGEvar(varname)]        /// Minimum wage variable
        [FEs(string)]                /// Fixed effects
        [WEIGHTvar(varname)]         /// Weight variable
        [CLUSTERvar(varname)]        /// Cluster variable
        [QCvar(varname)]             /// QC count variable
        [POSTvar(varname)]           /// Post-period indicator
        [STATEvar(varname)]          /// State indicator
        [QCpresvar(varname)]         /// QC presence indicator

    local outcome `varlist'

    ** Set defaults
    if "`postvar'" == "" local postvar "post"
    if "`statevar'" == "" local statevar "ca"
    if "`qcpresvar'" == "" local qcpresvar "qc_present"

    ** Loop over heterogeneity values
    local i = 1
    foreach h of numlist `hetvals' {

        ** Define sample condition
        if `h' == 0 {
            capture drop _het_samp
            gen _het_samp = 1
        }
        else {
            capture drop _het_samp
            gen _het_samp = (`hetvar' == `h')
        }

        ** Run regression with full controls (spec 4)
        eststo `estprefix'_`i': ///
            run_triple_diff `outcome' if _het_samp == 1, ///
                treatvar(`treatvar') ///
                controls(`controls') ///
                unempvar(`unempvar') ///
                minwagevar(`minwagevar') ///
                fes(`fes') ///
                weightvar(`weightvar') ///
                clustervar(`clustervar') ///
                qcvar(`qcvar')

        add_table_stats, outcome(`outcome') treatvar(`treatvar') ///
            postvar(`postvar') statevar(`statevar') qcvar(`qcpresvar') ///
            weightvar(`weightvar') samplecond(_het_samp == 1)
        add_spec_indicators, spec(4)

        ** Clean up
        drop _het_samp

        local i = `i' + 1
    }

end


** =============================================================================
** Display loaded programs
** =============================================================================

di _n "CalEITC utility programs loaded:"
di "  - qc_assignment: Assign qualifying children to adults"
di "  - run_triple_diff: Run triple-difference regression"
di "  - run_event_study: Run event study regression"
di "  - make_event_plot: Create event study coefficient plot"
di "  - get_pre_period_mean: Get treated group pre-period mean"
di "  - run_ppml_event_study: Run PPML event study regression"
di "  - run_ppml_regression: Run PPML regression with AME"
di "  - export_table_panel: Export regression results to LaTeX"
di "  - add_spec_indicators: Add specification indicators to estimates"
di "  - add_table_stats: Add common table statistics (ymean, C)"
di "  - export_spec_indicators: Export specification indicators table"
di "  - make_table_coefplot: Create coefficient plot from table estimates"
di "  - load_baseline_sample: Load ACS data with standard restrictions"
di "  - setup_did_vars: Create standard DID variables"
di "  - export_results: Export table to local and Overleaf"
di "  - run_all_specs: Run all 4 specifications for outcome"
di "  - export_event_coefficients: Export event study coefficients to CSV"
di "  - export_graph: Export graph to local and Overleaf"
di "  - run_heterogeneity_table: Run heterogeneity analysis"
