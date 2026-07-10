#!/bin/bash
#SBATCH --job-name=caleitc_s11dv
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=8:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage11_dv_%j.out

# Validate the deterministic layers of the R inference port against the
# stage-11 Stata dumps (needs stage11_inference_dump.sbatch to have completed).
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/validate/validate_inference_det.R
