#!/bin/bash
#SBATCH --job-name=caleitc_s19quadoster
#SBATCH --partition=day
#SBATCH --cpus-per-task=4
#SBATCH --mem=96G
#SBATCH --time=3:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage19_%j.out

# PLAN.md par A / C: quadruple-difference (college as a 4th dimension) +
# Oster (2019) coefficient-stability bounds, ported from
# 03_tab_quad_diff.do and 03_tab_oster_bounds.do. One working-file load
# (~30G); the quad-diff runs on the full college+non-college sample
# (~760k rows) with saturated 3-way FEs, hence the 96G headroom vs the
# 64G stage-17 job on the 462k baseline. Validates every quantity against
# the committed Stata golden outputs in-run. No seeds (all deterministic).
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/38_quad_oster.R
