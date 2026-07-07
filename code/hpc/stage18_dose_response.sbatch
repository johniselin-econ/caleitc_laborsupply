#!/bin/bash
#SBATCH --job-name=caleitc_s18dose
#SBATCH --partition=day
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=6:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage18_%j.out

# PLAN.md A.2 (Phase 3 robustness agenda): dose-response within non-college
# mothers as an exposure-design DiD (PLAN_siminstrument_note.md rec. 2) —
# sim-2 CalEITC exposure terciles, dose-group post ATTs + event studies,
# state-placebo RI (27 donors x 3 outcomes, spec 2). ~90 feols fits on the
# 462k baseline sample; deterministic, no seeds.
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/R/08_dose_response.R
