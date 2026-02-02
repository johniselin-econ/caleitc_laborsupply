/*******************************************************************************
File Name:      04_appA_fig_tcja_yctc.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Appendix A Figures: TCJA CTC and YCTC
                Benefit schedules for 2018-2019 with TCJA CTC and Young Child Tax Credit

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_fig_tcja_yctc
log using "${logs}04_appA_fig_tcja_yctc_log_${date}", name(log_04_appA_fig_tcja_yctc) replace text

** =============================================================================
** Create benefit schedule data using TAXSIM (following 03_fig_eitc_sched.do)
** =============================================================================

** Make TAXSIM Directory
capture mkdir "${data}taxsim"
cd "${data}taxsim"

** Loop over years 2017, 2018, 2019
foreach yr in 2017 2018 2019 {

    ** Generate earnings grid
    clear
    set obs 1001
    gen pwages = (_n - 1) * 50
    gen year = `yr'
    gen state = 5  // CA
    gen depx = 2   // Focus on 2 QC for this figure
    gen mstat = 1

    ** For YCTC (2019), need youngest child under 6
    if `yr' == 2019 {
        gen age1 = 4  // One child under 13
        gen age2 = 5  // One child under 17
    }

    ** Generate id
    gen taxsimid = _n

    ** Run through taxsim
    taxsimlocal35, full replace

    ** Keep relevant variables
    keep taxsimid year state depx pwages v25 v39 v22 v23

    ** Rename
    rename pwages earnings
    rename v25 fed_eitc
    rename v39 cal_eitc
    gen ctc = v22 + v23

    ** Save year-specific tempfile
    tempfile taxsim_`yr'
    save `taxsim_`yr''

} // END YEAR LOOP

** =============================================================================
** Combine years and prepare for plotting
** =============================================================================

** Append all years
clear
use `taxsim_2017'
append using `taxsim_2018'
append using `taxsim_2019'

** Move back to dir
cd $dir

** Replace 0s with missings for cleaner plotting
replace fed_eitc = . if fed_eitc == 0 & earnings != 0
replace cal_eitc = . if cal_eitc == 0 & earnings != 0
replace ctc = . if ctc == 0 & earnings != 0

** Generate YCTC variable (California's Young Child Tax Credit, 2019+)
** YCTC is $1,000 refundable credit for families with children under 6
** who qualify for CalEITC
gen yctc = 0
replace yctc = 1000 if year == 2019 & cal_eitc > 0 & cal_eitc != .
replace yctc = max(0, 1000 - 0.2 * (earnings - 25000)) if 	///
	year == 2019 & cal_eitc > 0 & cal_eitc != . & inrange(earnings, 25000, 30000)
replace yctc = . if yctc == 0 & earnings != 0

** Save combined benefit schedule
save "${data}interim/eitc_ctc_benefit_schedule_2017_2019.dta", replace

** =============================================================================
** Figure: CTC 2017-2018 comparison (TCJA changes)
** =============================================================================

twoway (line fed_eitc cal_eitc ctc earnings if year == 2017, ///
            lc(stc3 stc3 stc4) lp(solid dash solid)) ///
       (line ctc earnings if year == 2018, ///
            lc(stc4) lp(dash_dot)), ///
    legend(label(1 "Federal EITC") label(2 "CalEITC") ///
           label(3 "CTC (2017)") label(4 "CTC (2018)") ///
           order(1 2 3 4) col(1) ring(0) ///
           position(2) bmargin(large)) ///
    ylabel(0(1000)8000, format(%12.0fc)) ///
    xlabel(, format(%12.0fc)) ///
    ytitle("Benefit amount (nominal USD)") ///
    xtitle("Earned income (nominal USD)")

graph export "${results}figures/fig_appA_tcja_ctc.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_appA_tcja_ctc.jpg", as(jpg) name("Graph") quality(100) replace
}

** =============================================================================
** Figure: 2019 with YCTC
** =============================================================================

twoway (line fed_eitc cal_eitc ctc yctc earnings if year == 2019, ///
            lc(stc3 stc3 stc4 stc5) lp(solid dash solid solid)), ///
    legend(label(1 "Federal EITC") label(2 "CalEITC") ///
           label(3 "CTC") label(4 "YCTC") ///
           order(1 2 3 4) col(1) ring(0) ///
           position(2) bmargin(large)) ///
    ylabel(0(1000)8000, format(%12.0fc)) ///
    xlabel(, format(%12.0fc)) ///
    ytitle("Benefit amount (nominal USD)") ///
    xtitle("Earned income (nominal USD)")

graph export "${results}figures/fig_appA_yctc.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_appA_yctc.jpg", as(jpg) name("Graph") quality(100) replace
}

** END
clear
log close log_04_appA_fig_tcja_yctc
