#!/bin/bash
#SBATCH --job-name=caleitc_s21elast
#SBATCH --partition=day
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=2:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage21_%j.out

# Phase 4a: participation + mobility elasticities, mechanical port of
# 02_elasticities.do. Loads the 2 GB working file (exceeds the login-node
# memory cap) for the triple-diff participation piece; the mobility piece
# calls TAXSIM (~/ado/plus/t/taxsim35.exe) on 32 scenarios. Self-validates
# in-run against the committed Stata golden (logs.zip 02_elasticities_2026-03-07).
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/R/10_elasticities.R
