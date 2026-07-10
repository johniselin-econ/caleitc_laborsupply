#!/bin/bash
# =============================================================================
# run_pipeline.sh — submit a full re-run of the analysis pipeline from the
# existing working file (data/final/acs_working_file_r.rds).
#
# Submits the 12 compute stages (SDID/inference are 12-task arrays; the rest
# single jobs) in parallel — they depend only on the working file — then a
# final stage_exhibits job with --dependency=afterok on all of them, which
# stages the fresh outputs (stage_rerun.R), rebuilds the paper exhibits
# (00_run_all.R), and compiles the paper. Each compute stage self-validates
# in-run against the Stata golden (see its log in code/logs/).
#
# To re-run cleaning + the working file too, submit stage9_clean_years.sbatch
# and stage9_working_file.sbatch first and chain this after (see RUNBOOK.md).
#
# Usage:   bash code/hpc/run_pipeline.sh          # submit the chain
#          bash code/hpc/run_pipeline.sh --dry    # print the plan only
# =============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."   # repo root
DRY="${1:-}"

STAGES=(
  stage13_sdid_county.sbatch        # 10_sdid           (array 1-12)
  stage14_sdid_stateplacebo.sbatch  # 11_sdid_placebo   (array 1-12)
  stage15_sdid_eventstudy.sbatch    # 12_sdid_eventstudy(array 1-12)
  stage12_appE_battery.sbatch       # 20_altinference   (array 1-12)
  stage16_mw_bite.sbatch            # 30_mw_bite
  stage17_robustness_td.sbatch      # 33_robustness_td
  stage17b_earnbins_scale.sbatch    # 34_earnbins_scale
  stage18_dose_response.sbatch      # 36_dose_response
  stage19_quad_oster.sbatch         # 38_quad_oster
  stage21_elasticities.sbatch       # 50_elasticities
  stage22_mvpf.sbatch               # 51_mvpf
  stage20_appA_state_table.sbatch   # 60_state_tab (compute + exhibit)
)

if [ "$DRY" = "--dry" ]; then
  echo "Would submit ${#STAGES[@]} compute stages in parallel:"
  printf '  sbatch code/hpc/%s\n' "${STAGES[@]}"
  echo "then: sbatch --dependency=afterok:<all> code/hpc/stage_exhibits.sbatch"
  exit 0
fi

jids=()
for s in "${STAGES[@]}"; do
  id=$(sbatch --parsable "code/hpc/$s")
  echo "  submitted $s -> $id"
  jids+=("$id")
done
dep=$(IFS=:; echo "${jids[*]}")
fin=$(sbatch --parsable --dependency=afterok:"$dep" code/hpc/stage_exhibits.sbatch)
echo "  submitted stage_exhibits -> $fin  (runs after all ${#STAGES[@]} stages succeed)"
echo
echo "Track: squeue -u \$USER   |   logs: code/logs/slurm_*.out"
echo "On completion: paper/main_aejep.pdf rebuilt from the fresh results."
