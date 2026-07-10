#!/bin/bash
#SBATCH --job-name=caleitc_s9wf
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=3:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage9_wf_%j.out

# Assemble the combined working file (append + sim-2 cells + merge-back).
# Needs all per-year RDS files (stage9_clean_years.sbatch).
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/05_working_file.R
