#!/bin/bash
#SBATCH --job-name=caleitc_s14ripl
#SBATCH --partition=day
#SBATCH --array=1-12
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=6:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage14_%A_%a.out

# State-level placebo RI for the weighted county SDID (Phase 3 inference
# add-on to stage 13). One (outcome x spec) cell per array task; each is
# 1 actual + ~27 placebo full fits (no bootstrap) and writes
# data/tmp/sdid_county_stateplacebo_r_task<k>.{csv,rds}. No-cov cells are
# fast; cov cells redo the joint-beta optimization per placebo state, hence
# the headroom in the limit.
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/11_sdid_placebo.R
