#!/bin/bash
#SBATCH --job-name=caleitc_s16mwbite
#SBATCH --partition=day
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --time=2:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage16_%j.out

# PLAN.md A.1 minimum-wage bite test (Phase 3 / robustness agenda): county
# bite + CalEITC exposure measures from the 2012-14 working file, within-CA
# county DiD horse race, and ordinance-county-drop SDID refits. Single task;
# memory is for the working-file load (~30G in memory), SDID fits are cheap
# (no-cov triple, ~2.5 min each x 6).
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/30_mw_bite.R
