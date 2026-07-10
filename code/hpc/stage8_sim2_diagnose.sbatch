#!/bin/bash
#SBATCH --job-name=caleitc_s8diag
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=4:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage8_diag_%j.out

module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
# needs the stage8b golden dump (code/hpc/stage8_txpydump.do) on disk first
Rscript code/validate/diagnose_sim2_residual.R
