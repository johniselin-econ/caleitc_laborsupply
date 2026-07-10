#!/bin/bash
#SBATCH --job-name=caleitc_s9wfv
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=2:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage9_wfv_%j.out

# Validate the assembled working file against acs_working_file.dta.
# Needs acs_working_file_r.rds (stage9_working_file.sbatch).
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/validate/validate_working_file.R
