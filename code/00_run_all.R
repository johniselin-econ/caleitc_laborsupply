# =============================================================================
# File:    00_run_all.R
# Purpose: Master driver / orchestration map for the R pipeline. Run from the
#          repo root (renv activates via .Rprofile):
#              Rscript code/00_run_all.R
#
#          The heavy compute stages load the 2 GB working file (or TAXSIM) and
#          run as SLURM batch jobs (code/hpc/*.sbatch) — they CANNOT be sourced
#          on the login node. This driver therefore:
#            * runs the light / local steps directly (params + all exhibit
#              builders, which read the committed job-tagged results and write
#              the paper tables/figures), and
#            * documents the HPC compute stages and their sbatch, in order.
#          See RUNBOOK.md for the full re-run recipe (inputs/outputs/validation).
#
#          Toggle the switches below. Defaults: rebuild the exhibits locally,
#          skip downloads and HPC.
# Project: CalEITC Labor Supply Effects
# =============================================================================

source(file.path("code", "lib", "config.R"))
set.seed(params$seed)

## Switches -------------------------------------------------------------------
run_download     <- FALSE   # 01/02: IPUMS extract (~hours) + FIPS/BLS/min-wage
run_params       <- TRUE    # 03: CalEITC schedule params from the FTB tables
rebuild_exhibits <- TRUE    # 13..52: regenerate paper tables/figures locally
print_hpc_plan   <- TRUE    # print the ordered HPC compute recipe (no execution)

# =============================================================================
# (0) Data download — network, local  [01,02]
# =============================================================================
if (run_download) {
  project_root <- here::here(); dir_data_acs <- path_data("acs")
  api_codes_path <- cfg$api_codes
  start_year <- params$years$data_start; end_year <- params$years$data_end
  source(file.path("code", "01_download_acs.R"))
  dir_data_raw <- path_data("raw"); dir_data_int <- path_data("interim")
  start_year_data <- params$years$data_start; end_year_data <- params$years$data_end
  source(file.path("code", "02_download_aux.R"))
}
if (run_params) source(file.path("code", "03_caleitc_params.R"))

# =============================================================================
# (1) HPC compute stages — SLURM batch (documented; not sourced here)
#     Order matters: cleaning -> working file -> analysis. Submit each sbatch
#     and wait for it to stage its job-tagged results into results/ before the
#     exhibit builders below can consume them.
# =============================================================================
HPC <- c(
  "stage9_clean_years.sbatch        04_clean_acs.R        (per-year clean; needs data/acs + params)",
  "stage9_working_file.sbatch       05_working_file.R     (append + TAXSIM sim2; ~96 GB)",
  "stage13_sdid_county.sbatch       10_sdid.R             (SDID Table 2 fits)",
  "stage14_sdid_stateplacebo.sbatch 11_sdid_placebo.R     (state-placebo RI)",
  "stage15_sdid_eventstudy.sbatch   12_sdid_eventstudy.R  (weighted SDID event studies)",
  "stage12_appE_battery.sbatch      20_altinference.R     (alt-inference battery)",
  "stage16_mw_bite.sbatch           30_mw_bite.R          (min-wage bite test)",
  "stage17_robustness_td.sbatch     33_robustness_td.R    (Medicaid/alt-threshold/earn-density)",
  "stage17b_earnbins_scale.sbatch   34_earnbins_scale.R   (earnings-density scaled RI)",
  "stage18_dose_response.sbatch     36_dose_response.R    (dose-response)",
  "stage19_quad_oster.sbatch        38_quad_oster.R       (quad-diff + Oster)",
  "stage21_elasticities.sbatch      50_elasticities.R     (participation + mobility elasticities)",
  "stage22_mvpf.sbatch              51_mvpf.R             (MVPF grid)",
  "stage20_appA_state_table.sbatch  60_state_tab.R        (sample-states table)")
if (print_hpc_plan) {
  message("\n=== HPC compute stages (submit in order; see RUNBOOK.md) ===")
  for (h in HPC) message("  sbatch code/hpc/", h)
}

# =============================================================================
# (2) Exhibit builders — local; read committed job-tagged results  [13..52]
# =============================================================================
EXHIBITS <- c(
  "13_sdid_tab.R", "14_sdid_fig.R",           # Table 2 + SDID event-study figs
  "21_altinference_tab.R",                     # Appendix E inference table
  "32_honestdid.R",                            # HonestDiD sensitivity (rep matrices)
  "31_mw_bite_tab.R", "35_robustness_tab.R",   # threats + robustness tables
  "37_dose_tab.R", "39_quad_oster_tab.R",      # dose-response + quad/Oster tables
  "52_mvpf_fig.R")                             # MVPF distribution + spillover figs
if (rebuild_exhibits) {
  for (s in EXHIBITS) {
    message("--- ", s, " ---")
    source(file.path("code", s))
  }
}
# Note: 60_state_tab.R also builds an exhibit but loads the working file, so it
# runs on HPC (stage20) rather than here.

message("\n00_run_all.R complete.")
