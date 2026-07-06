#!/bin/bash
#SBATCH --job-name=caleitc_s10pnl
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=2:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage10_panel_%j.out

module load Stata/19
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
stata-mp -b do code/hpc/stage10_sdid_panel.do
# Stata batch mode always exits 0; detect failure from the log tail
tail -5 stage10_sdid_panel.log
grep -q "STAGE 10 COMPLETE" stage10_sdid_panel.log || { echo "STAGE 10 FAILED"; exit 1; }
