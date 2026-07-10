#!/bin/bash
#SBATCH --job-name=caleitc_s1
#SBATCH --partition=day
#SBATCH --cpus-per-task=16
#SBATCH --mem=120G
#SBATCH --time=23:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage1_%j.out

module load Stata/19
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
stata-mp -b do code/hpc/stage1.do
# Stata batch mode always exits 0; detect failure from the log tail
tail -5 stage1.log
grep -q "STAGE 1 COMPLETE" stage1.log || { echo "STAGE 1 FAILED"; exit 1; }
