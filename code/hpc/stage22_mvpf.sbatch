#!/bin/bash
#SBATCH --job-name=caleitc_s22mvpf
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=8:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage22_%j.out

# Phase 4b: MVPF port of 02_mvpf.do (deterministic expected-value assignment).
# Loads the 2 GB working file, precomputes TAXSIM liabilities for the treated
# PT-worker pool at all income levels, then runs the 9-deep spec grid (252
# regression keys x 3 counterfactuals = 756 model MVPFs). Self-validates the
# named specs against the 02_mvpf_log_2026-03-07 golden within MC tolerance.
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/R/11_mvpf.R
