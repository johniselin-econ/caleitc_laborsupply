#!/bin/bash
#SBATCH --job-name=caleitc_s3educ
#SBATCH --partition=day
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=1:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage3_educ_%j.out

module load Stata/19
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
stata-mp -b do code/hpc/stage3_educ.do
tail -5 stage3_educ.log
grep -q "STAGE 3 EDUC COMPLETE" stage3_educ.log || { echo "STAGE 3 EDUC FAILED"; exit 1; }
