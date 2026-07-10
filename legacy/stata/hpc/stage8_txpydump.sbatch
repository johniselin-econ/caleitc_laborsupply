#!/bin/bash
#SBATCH --job-name=caleitc_s8txpy
#SBATCH --partition=day
#SBATCH --cpus-per-task=16
#SBATCH --mem=120G
#SBATCH --time=2:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage8_txpy_%j.out

module load Stata/19
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
stata-mp -b do code/hpc/stage8_txpydump.do
tail -5 stage8_txpydump.log
grep -q "STAGE 8B TXPYDUMP COMPLETE" stage8_txpydump.log || { echo "STAGE 8B FAILED"; exit 1; }
