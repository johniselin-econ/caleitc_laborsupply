#!/bin/bash
#SBATCH --job-name=caleitc_s5ev
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=1:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage5_event_%j.out

module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/R/validate/validate_event_study.R
