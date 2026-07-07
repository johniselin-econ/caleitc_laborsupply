#!/bin/bash
#SBATCH --job-name=caleitc_s17bebins
#SBATCH --partition=day
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --time=1:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage17b_%j.out

# PLAN.md A.7 follow-up: per-state Kish n_eff + precision-scaled permutation
# statistic for the earnings-density test (see 07b_earnbins_scale.R header).
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/R/07b_earnbins_scale.R
