/*******************************************************************************
File Name:      04_appE_inference_parallel_shell.do
Creator:        John Iselin
Date Update:    January 2026

Purpose:        Creates Appendix E alternative inference procedures
                SHELL-BASED PARALLEL VERSION

                This version launches multiple Stata instances via shell commands
                More robust than the parallel package on Windows.

                Calculates p-values using:
                - Cluster-robust variance estimator (CRVE)
                - Wild cluster bootstrap (WCB)
                - Randomization inference wild bootstrap (RIWB)
                - Block bootstrap with Ferman-Pinto (2019) correction

Project: CalEITC Labor Supply Effects
*******************************************************************************/

** Start log file
capture log close log_04_appE_inference
log using "${logs}04_appE_inference_log_${date}", ///
    name(log_04_appE_inference) replace text

** =============================================================================
** Configuration
** =============================================================================

** Number of parallel Stata instances to run (adjust based on RAM/cores)
** Each instance needs ~2-4GB RAM
if missing("${ncores}") {
    local ncores = 4
}
else {
    local ncores = ${ncores}
}

** Path to Stata executable (adjust for your installation)
** Common paths:
**   - "C:\Program Files\Stata17\StataMP-64.exe" (Stata/MP)
**   - "C:\Program Files\Stata17\StataSE-64.exe" (Stata/SE)
**   - "C:\Program Files\Stata17\Stata-64.exe" (Stata/IC)
if missing("${stata_exe}") {
    local stata_exe `"C:\Program Files\Stata17\StataMP-64.exe"'
}
else {
    local stata_exe "${stata_exe}"
}

** =============================================================================
** Define parameters
** =============================================================================

local start = 2012
local end = 2017
local outcomes "full_time_y part_time_y"

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
** Prepare data (do once)
** =============================================================================

di _n "Preparing data for parallel workers..."

use if  female == 1 & ///
        married == 0 & ///
        in_school == 0 & ///
        age_sample_20_49 == 1 & ///
        citizen_test == 1 & ///
        state_status > 0 & ///
        education <= 3 & ///
        inrange(year, `start', `end') ///
    using "${data}final/acs_working_file.dta", replace

** Rescale outcome variables
foreach out of local outcomes {
    replace `out' = `out' * 100
}

** Create variables
gen ca = (state_fips == 6)
gen childXyearXca = cond(qc_present == 1 & ca == 1, year, 2014)
gen treated = (state_fips == 6 & qc_present == 1 & year >= 2015)
gen post = (year >= 2015)
label var treated "ATE"

replace hh_adult_ct = 3 if hh_adult_ct > 3
label define lb_adult_ct 1 "1" 2 "2" 3 "3+"
label values hh_adult_ct lb_adult_ct

gen minwage = mean_st_mw
label var minwage "Binding state minimum wage"

egen grp_state_year = group(state_fips year)
egen grp_state_qc = group(state_fips qc_ct)
egen grp_year_qc = group(year qc_ct)

gen pot_treat = (qc_present == 1) & (year >= 2015)

** Save prepared data
save "${data}interim/acs_prepared_for_inference.dta", replace

** =============================================================================
** Generate worker do-files
** =============================================================================

di _n "Generating worker do-files..."

local task_id = 1
foreach out of local outcomes {
    forvalues spec = 1/4 {

        ** Create worker do-file
        capture file close worker
        file open worker using "${code}tmp/worker_task`task_id'.do", write replace

        ** Write globals setup
        file write worker `"** Auto-generated worker for task `task_id'"' _n
        file write worker `"** Outcome: `out', Specification: `spec'"' _n _n

        ** Write global definitions (inherit from master)
        file write worker `"global data "${data}""' _n
        file write worker `"global code "${code}""' _n
        file write worker `"global results "${results}""' _n
        file write worker `"global logs "${logs}""' _n
        file write worker `"global seed ${seed}"' _n
        file write worker `"global debug ${debug}"' _n _n

        ** Write task parameters
        file write worker `"local task_id = `task_id'"' _n
        file write worker `"local out "`out'""' _n
        file write worker `"local spec = `spec'"' _n
        file write worker `"local B = `B'"' _n
        file write worker `"local B_ri = `B_ri'"' _n
        file write worker `"local debug_text "`debug_text'""' _n _n

        ** Include programs and run
        file write worker `"** Load programs"' _n
        file write worker `"do "\${code}04_appE_inference_programs.do""' _n _n

        file write worker `"** Run worker task"' _n
        file write worker `"do "\${code}04_appE_inference_task.do""' _n

        file close worker

        local task_id = `task_id' + 1
    }
}

** =============================================================================
** Create the task runner do-file
** =============================================================================

capture file close taskfile
file open taskfile using "${code}04_appE_inference_task.do", write replace

file write taskfile `"/*******************************************************************************"' _n
file write taskfile `"Worker task runner - executes a single outcome x specification combination"' _n
file write taskfile `"*******************************************************************************/"' _n _n

file write taskfile `"** Load prepared data"' _n
file write taskfile `"use "\${data}interim/acs_prepared_for_inference.dta", clear"' _n _n

file write taskfile `"** Define specifications"' _n
file write taskfile `"local did1 "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct""' _n
file write taskfile `"local unemp1 """' _n
file write taskfile `"local controls1 """' _n _n

file write taskfile `"local did2 "`did1'""' _n
file write taskfile `"local unemp2 """' _n
file write taskfile `"local controls2 "education age_bracket minage_qc race_group hispanic hh_adult_ct""' _n _n

file write taskfile `"local did3 "`did1'""' _n
file write taskfile `"local unemp3 "c.state_unemp#i.qc_ct""' _n
file write taskfile `"local controls3 "`controls2'""' _n _n

file write taskfile `"local did4 "`did1'""' _n
file write taskfile `"local unemp4 "`unemp3' c.minwage#i.qc_ct""' _n
file write taskfile `"local controls4 "`controls2'""' _n _n

file write taskfile `"local absorb1_areg "grp_state_year""' _n
file write taskfile `"local did1_areg "i.state_fips i.qc_ct i.year i.grp_state_qc i.grp_year_qc""' _n
file write taskfile `"local controls1_areg """' _n _n

file write taskfile `"local absorb2_areg "`absorb1_areg'""' _n
file write taskfile `"local did2_areg "`did1_areg'""' _n
file write taskfile `"local controls2_areg "i.education i.age_bracket i.minage_qc i.race_group i.hispanic i.hh_adult_ct""' _n _n

file write taskfile `"local absorb3_areg "`absorb1_areg'""' _n
file write taskfile `"local did3_areg "`did1_areg'""' _n
file write taskfile `"local controls3_areg "`controls2_areg'""' _n _n

file write taskfile `"local absorb4_areg "`absorb1_areg'""' _n
file write taskfile `"local did4_areg "`did1_areg'""' _n
file write taskfile `"local controls4_areg "`controls2_areg'""' _n _n

file write taskfile `"** Set locals for this specification"' _n
file write taskfile `"local did "`did`spec''""' _n
file write taskfile `"local unemp "`unemp`spec''""' _n
file write taskfile `"local controls "`controls`spec''""' _n
file write taskfile `"local absorb "`absorb`spec'_areg'""' _n
file write taskfile `"local did_areg "`did`spec'_areg'""' _n
file write taskfile `"local controls_areg "`controls`spec'_areg'""' _n _n

file write taskfile `"di _n "Task `task_id': Running `out', spec `spec'""' _n _n

file write taskfile `"** -----------------------------------------------------------------------------"' _n
file write taskfile `"** Wild Cluster Bootstrap"' _n
file write taskfile `"** -----------------------------------------------------------------------------"' _n
file write taskfile `"di "  - Wild Cluster Bootstrap...""' _n _n

file write taskfile `"wildbootstrap ///"' _n
file write taskfile `"    areg `out' treated `unemp' `did_areg' `controls_areg' ///"' _n
file write taskfile `"    [aw = weight], ///"' _n
file write taskfile `"    absorb(`absorb') ///"' _n
file write taskfile `"    cluster(state_fips) ///"' _n
file write taskfile `"    coefficients(treated) ///"' _n
file write taskfile `"    reps(`B') ///"' _n
file write taskfile `"    rseed(\${seed})"' _n _n

file write taskfile `"local p_wcbs = e(wboot)[1,3]"' _n _n

file write taskfile `"** -----------------------------------------------------------------------------"' _n
file write taskfile `"** Randomization Inference Wild Bootstrap"' _n
file write taskfile `"** -----------------------------------------------------------------------------"' _n
file write taskfile `"di "  - RI Wild Bootstrap...""' _n _n

file write taskfile `"ri_bs_par `out' treated "`did'" "`controls'" "`unemp'" ///"' _n
file write taskfile `"    state_fips weight `B_ri' pot_treat ///"' _n
file write taskfile `"    "\${data}interim/data_`out'_`spec'_riwcbs`debug_text'.dta""' _n _n

file write taskfile `"local p_riwcbs_b = `r(p_beta)'"' _n
file write taskfile `"local p_riwcbs_t = `r(p_t)'"' _n _n

file write taskfile `"** -----------------------------------------------------------------------------"' _n
file write taskfile `"** Ferman-Pinto Block Bootstrap"' _n
file write taskfile `"** -----------------------------------------------------------------------------"' _n
file write taskfile `"di "  - Ferman-Pinto Bootstrap...""' _n _n

file write taskfile `"ferman_pinto_boot_ind_par `out' treated "`did'" "`controls'" "`unemp'" ///"' _n
file write taskfile `"    state_fips year qc_present weight `B' ///"' _n
file write taskfile `"    "\${data}interim/data_`out'_`spec'_fp2019`debug_text'.dta""' _n _n

file write taskfile `"local p_block_fp = `r(p_with)'"' _n
file write taskfile `"local p_block = `r(p_without)'"' _n _n

file write taskfile `"** -----------------------------------------------------------------------------"' _n
file write taskfile `"** CRVE Regression"' _n
file write taskfile `"** -----------------------------------------------------------------------------"' _n
file write taskfile `"di "  - CRVE regression...""' _n _n

file write taskfile `"reghdfe `out' treated `unemp' [aw = weight], ///"' _n
file write taskfile `"    absorb(`did' `controls') ///"' _n
file write taskfile `"    vce(cluster state_fips)"' _n _n

file write taskfile `"local beta = _b[treated]"' _n
file write taskfile `"local se = _se[treated]"' _n
file write taskfile `"local t = `beta' / `se'"' _n
file write taskfile `"local p_crve = 2 * ttail(e(df_r), abs(`t'))"' _n
file write taskfile `"local N = e(N)"' _n _n

file write taskfile `"** -----------------------------------------------------------------------------"' _n
file write taskfile `"** Save results"' _n
file write taskfile `"** -----------------------------------------------------------------------------"' _n _n

file write taskfile `"clear"' _n
file write taskfile `"set obs 1"' _n _n

file write taskfile `"gen task_id = `task_id'"' _n
file write taskfile `"gen outcome = "`out'""' _n
file write taskfile `"gen spec = `spec'"' _n
file write taskfile `"gen beta = `beta'"' _n
file write taskfile `"gen se = `se'"' _n
file write taskfile `"gen N = `N'"' _n
file write taskfile `"gen p_crve = `p_crve'"' _n
file write taskfile `"gen p_wcbs = `p_wcbs'"' _n
file write taskfile `"gen p_riwcbs_b = `p_riwcbs_b'"' _n
file write taskfile `"gen p_riwcbs_t = `p_riwcbs_t'"' _n
file write taskfile `"gen p_block = `p_block'"' _n
file write taskfile `"gen p_block_fp = `p_block_fp'"' _n _n

file write taskfile `"save "\${data}interim/inference_results_task`task_id'.dta", replace"' _n _n

file write taskfile `"di _n "Task `task_id' complete.""' _n

file close taskfile

** =============================================================================
** Create batch file to launch parallel Stata instances
** =============================================================================

di _n "Creating batch launcher..."

capture file close batch
file open batch using "${code}tmp/run_parallel_inference.bat", write replace

file write batch `"@echo off"' _n
file write batch `"echo Starting parallel inference estimation..."' _n
file write batch `"echo Launching 8 Stata instances..."' _n _n

** Launch tasks in batches based on ncores
local batch_size = `ncores'
local num_batches = ceil(8 / `batch_size')

forvalues batch = 1/`num_batches' {
    local start_task = (`batch' - 1) * `batch_size' + 1
    local end_task = min(`batch' * `batch_size', 8)

    file write batch `"echo."' _n
    file write batch `"echo Batch `batch': Tasks `start_task'-`end_task'"' _n

    forvalues t = `start_task'/`end_task' {
        file write batch `"start "" "`stata_exe'" /e do "${code}tmp/worker_task`t'.do""' _n
    }

    ** Wait for batch to complete before starting next (check for result files)
    if `batch' < `num_batches' {
        file write batch `"echo Waiting for batch `batch' to complete..."' _n
        file write batch `":wait_batch`batch'"' _n
        file write batch `"timeout /t 10 /nobreak >nul"' _n

        forvalues t = `start_task'/`end_task' {
            file write batch `"if not exist "${data}tmp\inference_results_task`t'.dta" goto wait_batch`batch'"' _n
        }
    }
}

file write batch `"echo."' _n
file write batch `"echo Waiting for final tasks to complete..."' _n
file write batch `":wait_final"' _n
file write batch `"timeout /t 10 /nobreak >nul"' _n
forvalues t = 1/8 {
    file write batch `"if not exist "${data}tmp\inference_results_task`t'.dta" goto wait_final"' _n
}

file write batch `"echo."' _n
file write batch `"echo All tasks complete!"' _n

file close batch

** =============================================================================
** Option 1: Run via shell (launches background processes)
** =============================================================================

di _n "Launching parallel workers via shell..."
di "Each worker runs in a separate Stata instance."
di ""

** Launch all workers
forvalues t = 1/8 {
    di "  Launching task `t'..."
    winexec "`stata_exe'" /e do "${code}tmp/worker_task`t'.do"

    ** Stagger launches slightly to avoid file conflicts
    sleep 2000
}

di _n "All workers launched. Waiting for completion..."

** =============================================================================
** Wait for all tasks to complete
** =============================================================================

local all_done = 0
local wait_time = 0
local max_wait = 7200  // 2 hours max wait

while `all_done' == 0 & `wait_time' < `max_wait' {
    sleep 30000  // Check every 30 seconds
    local wait_time = `wait_time' + 30

    local completed = 0
    forvalues t = 1/8 {
        capture confirm file "${data}interim/inference_results_task`t'.dta"
        if _rc == 0 {
            local completed = `completed' + 1
        }
    }

    di "  Progress: `completed'/8 tasks complete (elapsed: `wait_time's)"

    if `completed' == 8 {
        local all_done = 1
    }
}

if `all_done' == 0 {
    di as error "Timeout waiting for workers. Check individual log files."
    exit 1
}

di _n "All workers completed successfully."

** =============================================================================
** Combine results
** =============================================================================

di _n "Combining results..."

clear
forvalues t = 1/8 {
    if `t' == 1 {
        use "${data}interim/inference_results_task`t'.dta", clear
    }
    else {
        append using "${data}interim/inference_results_task`t'.dta"
    }
}

sort outcome spec
save "${data}interim/inference_results_combined`debug_text'.dta", replace

** =============================================================================
** Generate output tables
** =============================================================================

di _n "Generating output tables..."

use "${data}interim/acs_prepared_for_inference.dta", clear

** Define specifications
local did1 "qc_ct year state_fips state_fips#year state_fips#qc_ct year#qc_ct"
local unemp1 ""
local controls1 ""

local did2 "`did1'"
local unemp2 ""
local controls2 "education age_bracket minage_qc race_group hispanic hh_adult_ct"

local did3 "`did1'"
local unemp3 "c.state_unemp#i.qc_ct"
local controls3 "`controls2'"

local did4 "`did1'"
local unemp4 "`unemp3' c.minwage#i.qc_ct"
local controls4 "`controls2'"

** Load results
preserve
use "${data}interim/inference_results_combined`debug_text'.dta", clear
tempfile results
save `results'
restore

** Generate tables
local i = 1
foreach out in full_time_y part_time_y {

    forvalues spec = 1/4 {

        local did "`did`spec''"
        local unemp "`unemp`spec''"
        local controls "`controls`spec''"

        eststo `out'_`spec': ///
            reghdfe `out' treated `unemp' [aw = weight], ///
            absorb(`did' `controls') ///
            vce(cluster state_fips)

        ** Get p-values from results
        preserve
        use `results', clear
        keep if outcome == "`out'" & spec == `spec'

        local p_crve = p_crve[1]
        local p_wcbs = p_wcbs[1]
        local p_riwcbs_b = p_riwcbs_b[1]
        local p_riwcbs_t = p_riwcbs_t[1]
        local p_block = p_block[1]
        local p_block_fp = p_block_fp[1]

        restore

        estadd scalar p_crve = `p_crve'
        estadd scalar p_wcbs = `p_wcbs'
        estadd scalar p_riwcbs_b = `p_riwcbs_b'
        estadd scalar p_riwcbs_t = `p_riwcbs_t'
        estadd scalar p_block = `p_block'
        estadd scalar p_block_fp = `p_block_fp'
    }

    ** Export table
    local stats_list "N p_crve p_wcbs p_riwcbs_b p_riwcbs_t p_block p_block_fp"
    local stats_fmt "%9.0fc %9.3fc %9.3fc %9.3fc %9.3fc %9.3fc %9.3fc"

    local stats_labels `" "  Observations" "'
    local stats_labels `" `stats_labels' "  CRVE P-Value" "'
    local stats_labels `" `stats_labels' "  WCBS P-Value" "'
    local stats_labels `" `stats_labels' "  RIWB-t P-Value" "'
    local stats_labels `" `stats_labels' "  RIWB-b P-Value" "'
    local stats_labels `" `stats_labels' "  BB P-Value" "'
    local stats_labels `" `stats_labels' "  Corrected BB P-Value" "'

    esttab `out'_* using ///
        "${results}tables/tab_appE_tab1_`i'`debug_text'.tex", ///
        booktabs fragment nobaselevels replace nomtitles nonumbers ///
        stats(`stats_list', ///
            fmt("`stats_fmt'") labels(`stats_labels')) ///
        b(1) se(1) label order(treated) keep(treated) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        prehead("\\ \midrule") nolines

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

    local i = `i' + 1
}

** =============================================================================
** Cleanup
** =============================================================================

** Remove temporary worker files
forvalues t = 1/8 {
    capture erase "${code}tmp/worker_task`t'.do"
    capture erase "${data}interim/inference_results_task`t'.dta"
}
capture erase "${code}tmp/run_parallel_inference.bat"

di _n "Parallel inference complete."

clear
log close log_04_appE_inference
