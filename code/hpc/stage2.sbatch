#!/bin/bash
#SBATCH --job-name=caleitc_s2
#SBATCH --partition=day
#SBATCH --cpus-per-task=16
#SBATCH --mem=120G
#SBATCH --time=23:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage2_%j.out

module load Stata/19
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
stata-mp -b do code/hpc/stage2.do
tail -5 stage2.log
grep -q "STAGE 2 COMPLETE" stage2.log || { echo "STAGE 2 FAILED"; exit 1; }
