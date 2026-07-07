#!/bin/bash
#SBATCH --job-name=caleitc_s17robust
#SBATCH --partition=day
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=3:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage17_%j.out

# PLAN.md A.3 / A.5 / A.7 (Phase 3 robustness agenda): Medicaid-expansion
# control pool triple-diff + event studies, alternative FT thresholds
# (31/39), and the earnings-density permutation test. One working-file
# load (~30G in memory); ~30 feols fits on the 462k baseline sample plus
# a cheap state-level collapse. No seeds (permutation is exhaustive).
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/R/07_robustness_td.R
