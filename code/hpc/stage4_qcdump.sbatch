#!/bin/bash
#SBATCH --job-name=caleitc_s4qc
#SBATCH --partition=day
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --time=2:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage4_qcdump_%j.out

module load Stata/19
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
stata-mp -b do code/hpc/stage4_qcdump.do
tail -5 stage4_qcdump.log
grep -q "STAGE 4 QC DUMP COMPLETE" stage4_qcdump.log || { echo "STAGE 4 FAILED"; exit 1; }
