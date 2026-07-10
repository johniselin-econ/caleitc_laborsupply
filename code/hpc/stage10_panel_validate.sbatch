#!/bin/bash
#SBATCH --job-name=caleitc_s10pv
#SBATCH --partition=day
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=1:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage10_pv_%j.out

# Build the SDID county panel in R and validate against the Stata golden
# file (needs stage10_sdid_panel.sbatch to have completed).
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/validate/validate_sdid_panel.R
