/*******************************************************************************
File Name:      03_fig_eitc_sched.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Figure 1
                Federal and California EITC benefits schedule

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_fig_eitc_sched
log using "${logs}04_fig_eitc_sched_log_${date}", name(log_04_fig_eitc_sched) replace text

** =============================================================================
** Create EITC benefit schedule data
** =============================================================================

** Make TAXSIM Directory 
capture mkdir "${data}taxsim"
cd  "${data}taxsim"

** Loop over years
forvalues y = 2015(2)2017 {
	

	** Generate earnings 
	clear
	set obs 1001
	gen pwages = 	(_n - 1) * 50 
	gen year = `y'
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
	keep year state depx pwages v25 v39 

	** Rename 
	rename depx qc 
	rename pwages earnings 
	rename v25 fed_eitc_ 
	rename v39 cal_eitc_ 
	gen tot_eitc_ = fed_eitc_ + cal_eitc_

	** Replace 0s with missings 
	replace tot_eitc_ = . if tot_eitc_ == 0 & earnings != 0 
	replace fed_eitc_ = . if fed_eitc_ == 0 & earnings != 0 
	replace cal_eitc_ = . if cal_eitc_ == 0 & earnings != 0 

	** Reshape 
	reshape wide fed_eitc_ cal_eitc_ tot_eitc_, i(year state earnings) j(qc)

	** =============================================================================
	** Create Figure 1: EITC Schedule by Number of QC
	** =============================================================================

	** Panel A: Federal and CA EITC (use scheme colors)
	twoway ///
		(line fed_eitc_0 earnings, lcolor(gs10) lpattern(solid))	///
		(line fed_eitc_1 earnings, lcolor(stc1) lpattern(solid))	///
		(line fed_eitc_2 earnings, lcolor(stc2) lpattern(solid))	///
		(line fed_eitc_3 earnings, lcolor(stc3) lpattern(solid))	///
		(line cal_eitc_0 earnings, lcolor(gs10) lpattern(dash)) 	///
		(line cal_eitc_1 earnings, lcolor(stc1) lpattern(dash)) 	///
		(line cal_eitc_2 earnings, lcolor(stc2) lpattern(dash)) 	///
		(line cal_eitc_3 earnings, lcolor(stc3) lpattern(dash)),	///
		legend(order(1 "Fed, 0 QC" 2 "Fed, 1 QC" 3 "Fed, 2 QC" 4 "Fed, 3+ QC"	///
					 5 "CA, 0 QC" 6 "CA, 1 QC" 7 "CA, 2 QC" 8 "CA, 3+ QC")		///
			pos(6) row(2) size(small)) ///
		xtitle("Earned Income ($)") ///
		ytitle("EITC Benefit ($), Federal vs. California") ///
		xlabel(0(10000)50000, format(%9.0fc) labsize(small)) ///
		ylabel(0(1000)7000, format(%9.0fc) labsize(small))

	** Save locally
	graph export "${results}figures/fig_appA_eitc_`y'.jpg", ///
		as(jpg) name("Graph") quality(100) replace

	** Save to overleaf if ${overleaf} == 1
	if ${overleaf} == 1 {
		graph export "${ol_fig}fig_appA_eitc_`y'.jpg", as(jpg) name("Graph") quality(100) replace
	}	
		
		
	clear 
	
} // END YEAR LOOP 
	
** =============================================================================
** End
** =============================================================================

log close log_04_fig_eitc_sched
