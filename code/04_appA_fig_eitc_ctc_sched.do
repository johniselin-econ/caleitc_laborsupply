/*******************************************************************************
File Name:      04_appA_eitc_ctc_sched.do
Creator:        John Iselin
Date Update:    February 2026

Purpose:        Creates Appendix A Figures 2a, 2b, 2c, and 2d
                Benefit schedules for the federal EITC, CTC, and CalEITC for TY 2016

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appA_eitc_ctc_sched
log using "${logs}04_appA_eitc_ctc_sched_log_${date}", name(log_04_appA_eitc_ctc_sched) replace text

** =============================================================================
** Create benefit schedule data using TAXSIM (following 03_fig_eitc_sched.do)
** =============================================================================

** Make TAXSIM Directory
capture mkdir "${data}taxsim"
cd "${data}taxsim"

** Generate earnings grid
clear
set obs 1001
gen pwages = (_n - 1) * 50
gen year = 2016
gen state = 5  // CA
gen depx = .
gen mstat = 1

** Tempfile
tempfile taxsimdata
save `taxsimdata'
clear

** Append data in loop to get # QC
forvalues x = 0/3 {
	append using `taxsimdata'
	replace depx = `x' if missing(depx)
} // END QC LOOP

** Generate id
gen taxsimid = _n

** Run through taxsim
taxsimlocal35, full replace

** Move back to dir
cd $dir

** Organize data
keep year state depx pwages v25 v39 v22 v23 

** Rename variables
rename depx qc
rename pwages earnings
rename v25 fed_eitc
rename v39 cal_eitc
gen ctc = v22 + v23

** Calculate total credits
gen tot_cred = fed_eitc + cal_eitc + ctc

** Replace 0s with missings for cleaner plotting
replace fed_eitc = . if fed_eitc == 0 & earnings != 0
replace cal_eitc = . if cal_eitc == 0 & earnings != 0
replace ctc = . if ctc == 0 & earnings != 0

** Save benefit schedule
save "${data}interim/eitc_ctc_benefit_schedule_2016.dta", replace

** =============================================================================
** Create Figures 2a-2d: Benefit schedules by QC count
** =============================================================================

** Loop over QC count
forvalues q = 0(1)3 {

    if `q' == 0 {
        local cl "stc1"
        local stub "a"
    }
    if `q' == 1 {
        local cl "stc2"
        local stub "b"
    }
    if `q' == 2 {
        local cl "stc3"
        local stub "c"
    }
    if `q' == 3 {
        local cl "stc6"
        local stub "d"
    }

    ** Figure: Federal EITC, CalEITC, CTC, and Total by QC
    twoway line fed_eitc cal_eitc ctc tot_cred earnings if qc == `q', ///
        ytitle("EITC and CTC Benefit ($)") 							///
        xtitle("Earned income ($)") ///
        lc(`cl' `cl' stc4 black) lp(solid dash solid solid) ///
        legend(label(1 "Federal EITC") label(2 "CalEITC") ///
               label(3 "CTC") label(4 "All Credits") ///
               order(1 2 3 4) col(1) ring(0) position(2) bmargin(large)) ///
		xlabel(0(10000)50000, format(%9.0fc) labsize(small)) ///
		ylabel(0(1000)7000, format(%9.0fc) labsize(small))
    ** Save locally
    graph export "${results}figures/fig_appA_eitc_ctc_sched`stub'.jpg", ///
        as(jpg) name("Graph") quality(100) replace

    ** Save to overleaf if ${overleaf} == 1
    if ${overleaf} == 1 {
        graph export "${ol_fig}fig_appA_eitc_ctc_sched`stub'.jpg", as(jpg) name("Graph") quality(100) replace
    }

} // END QC LOOP

** END
clear
log close log_04_appA_eitc_ctc_sched
