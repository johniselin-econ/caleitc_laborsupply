#!/bin/bash
#SBATCH --job-name=caleitc_s9cl
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=2:00:00
#SBATCH --array=2006-2013,2015-2019%8
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage9_clean_%A_%a.out

# Build the per-year cleaned RDS files (Steps 1-8 + TAXSIM sims 1/3 for
# 2010-2019). 2014 already exists from job 17096067.
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/R/01_clean_data.R $SLURM_ARRAY_TASK_ID
