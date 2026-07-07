#!/bin/bash
#SBATCH --job-name=caleitc_s13sdid
#SBATCH --partition=day
#SBATCH --array=1-12
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=12:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage13_%A_%a.out

# SDID Table 2 re-estimation on the synthdid_weights fork (Phase 3).
# One (outcome x spec) cell per array task; each writes
# data/tmp/sdid_county_r_task<k>.{csv,rds}. Cov-spec bootstraps redo the
# fork's joint-beta optimization per replicate (~90 min/variant), hence the
# split and the 12h limit; no-cov tasks finish in ~30 min.
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/R/03_sdid_county.R
