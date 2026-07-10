#!/bin/bash
#SBATCH --job-name=caleitc_s8dump
#SBATCH --partition=day
#SBATCH --cpus-per-task=16
#SBATCH --mem=120G
#SBATCH --time=4:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage8_dump_%j.out

module load Stata/19
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
stata-mp -b do code/hpc/stage8_sim2dump.do
tail -5 stage8_sim2dump.log
grep -q "STAGE 8 SIM2 DUMP COMPLETE" stage8_sim2dump.log || { echo "STAGE 8 FAILED"; exit 1; }
