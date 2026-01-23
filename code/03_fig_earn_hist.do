/*******************************************************************************
File Name:      03_fig_earn_hist.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Figure 2
                Fig 2a. Histogram of single women workers in 2014 by full- and 
					part-time status
				Fig 2b. Histogram of workers with QC, by marital status and sex

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_03_fig_earn_hist
log using "${logs}03_fig_earn_hist_log_${date}", name(log_03_fig_earn_hist) replace text


** FIGURE 2a

** Parameters
local y = 2014  // YEAR

** Load ACS data
use weight incearn_nom part_time_y full_time_y year ///
    female married in_school age citizen_test state_fips ///
    if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        inrange(age, 20, 49) & ///
        citizen_test == 1 & ///
        state_fips == 6 & ///
        year == `y' ///
    using ${data}final/acs_working_file, clear

** Generate integer weights
gen weight_int = round(weight)

** Generate required variables
gen incearn_topcode = incearn_nom
replace incearn_topcode = 150000 if incearn_topcode > 150000 & !missing(incearn_topcode)

** EITC PARAMETERS (2015)

** 2015 Federal EITC parameters (2 QC)
local fed_mc = 5460
local fed_pi = 0.4
local fed_po = 0.2106
local fed_kink1 = 13650
local fed_kink2 = 17830
local fed_kink3 = 43765

** 2015 CalEITC parameters (2 QC)
local cal_mc = 2358
local cal_pi = 0.338
local cal_po = 0.339
local cal_kink1 = 6925.5
local cal_kink2 = `cal_mc' / `cal_po' + `cal_kink1'

** Minwage marks
local minwage = 9 * 40 * 52

** Histogram of earnings by full vs part-time status
twoway  (hist incearn_topcode if part_time_y == 1 & year == 2014 ///
            [fw = weight_int], ///
            fcolor(stc1) lcolor(stc1) width(5000) frequency) ///
        (hist incearn_topcode if full_time_y == 1 & year == 2014 ///
            [fw = weight_int], ///
            fcolor(none) lcolor(black) width(5000) frequency) ///
        (function y = x * `cal_pi', /// CALEITC
            range(0 `cal_kink1') yaxis(2) lc(red) lp(dash)) ///
        (function y = `cal_mc' - (x - `cal_kink1') * `cal_po', ///
            range(`cal_kink1' `cal_kink2') ///
            yaxis(2) lc(red) lp(dash)) ///
        (function y = x * `fed_pi', /// FEDEITC
            range(0 `fed_kink1') yaxis(2) lc(black) lp(dash)) ///
        (function y = `fed_mc', ///
            range(`fed_kink1' `fed_kink2') ///
            yaxis(2) lc(black) lp(dash)) ///
        (function y = `fed_mc' - (x - `fed_kink2') * `fed_po', ///
            range(`fed_kink2' `fed_kink3') ///
            yaxis(2) lc(black) lp(dash)), ///
        legend(order(1 "Part-time" 2 "Full-time" ///
                     3 "CalEITC" 6 "Federal EITC") ///
               ring(0) position(2) bmargin(large)) ///
        xtitle("Topcoded earned income (2014 USD)") ///
        ytitle("Weighted count of workers") ///
        ylabel(,format(%12.0fc)) xlabel(,format(%12.0fc)) ///
        ylabel(none, axis(2)) ///
        ytitle("", axis(2)) yscale(lstyle(none) axis(2))

** Save locally
graph export "${results}paper/fig_earn_hist_a.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_earn_hist_a.jpg", as(jpg) name("Graph") quality(100) replace
}


** CLear 
clear 


** FIGURE 2b

** Load ACS data
use weight incearn_tax_nom part_time_y full_time_y year qc_present 		///
    female married in_school age citizen_test state_fips cpi99			///
    if  in_school == 0 & ///
		qc_present == 1 & ///
        inrange(age, 20, 49) & ///
        citizen_test == 1 & ///
        state_fips == 6 & ///
        inrange(year, 2012,2014) ///
    using ${data}final/acs_working_file, clear

** Generate integer weights
gen weight_int = round(weight)

** Keep if employed 
keep if full_time_y == 1 | part_time_y == 1 

** Inflate to 2014 dollars 
qui summ cpi99 if year == 2014
local cpi_14 = r(mean)
gen incearn_real = incearn_tax_nom * cpi99 / `cpi_14' 

** Generate required variables
gen incearn_topcode = incearn_real
replace incearn_topcode = 150000 if incearn_topcode > 150000 & !missing(incearn_topcode)

** Generate bins 
gen bin = 1 if female == 1 & married == 0 
replace bin = 2 if female == 1 & married == 1
replace bin = 3 if female == 0 & married == 0
replace bin = 4 if female == 0 & married == 1
label var bin "Bins by Sex and Marital Status"
label define lb_bin 1 "Single Women" 2 "Married Women" 3 "Single Men" 4 "Married Men", replace 
label values bin lb_bin


** Histogram of earnings by full vs part-time status
twoway  (hist incearn_topcode [fw = weight_int], 					///
            fcolor(stc1) lcolor(stc1) width(5000) frequency) 		///
        (function y = x * `cal_pi', 								/// CALEITC
            range(0 `cal_kink1') yaxis(2) lc(red) lp(dash)) 		///
        (function y = `cal_mc' - (x - `cal_kink1') * `cal_po', 		///
            range(`cal_kink1' `cal_kink2') 							///
            yaxis(2) lc(red) lp(dash)) 								///
        (function y = x * `fed_pi', 								/// FEDEITC
            range(0 `fed_kink1') yaxis(2) lc(black) lp(dash)) 		///
        (function y = `fed_mc', 									///
            range(`fed_kink1' `fed_kink2') 							///
            yaxis(2) lc(black) lp(dash)) 							///
        (function y = `fed_mc' - (x - `fed_kink2') * `fed_po', 		///
            range(`fed_kink2' `fed_kink3') 							///
            yaxis(2) lc(black) lp(dash)), 							///
		by(bin, legend(pos(6)))										///
		legend(order(3 "CalEITC" 6 "Federal EITC")  row(1))			///
		ylabel(,format(%12.0fc)) xlabel(,format(%12.0fc)) 			///
        ytitle("", axis(2)) yscale(lstyle(none) axis(2)) 			///
        xtitle("Topcoded earned income (2014 USD)") 				///
        ytitle("Weighted count of workers") ylabel(none, axis(2))
       
** Save locally
graph export "${results}paper/fig_earn_hist_b.jpg", ///
    as(jpg) name("Graph") quality(100) replace

** Save to overleaf if ${overleaf} == 1
if ${overleaf} == 1 {
    graph export "${ol_fig}fig_earn_hist_b.jpg", as(jpg) name("Graph") quality(100) replace
}



** END
clear
log close log_03_fig_earn_hist
