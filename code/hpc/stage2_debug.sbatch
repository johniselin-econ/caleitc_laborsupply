#!/bin/bash
#SBATCH --job-name=caleitc_s2dbg
#SBATCH --partition=day
#SBATCH --cpus-per-task=16
#SBATCH --mem=120G
#SBATCH --time=4:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage2_debug_%j.out

module load Stata/19
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
stata-mp -b do code/hpc/stage2_debug.do
tail -5 stage2_debug.log
grep -q "STAGE 2 DEBUG COMPLETE" stage2_debug.log || { echo "STAGE 2 DEBUG FAILED"; exit 1; }
