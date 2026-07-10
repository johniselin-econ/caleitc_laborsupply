#!/bin/bash
#SBATCH --job-name=caleitc_s11det
#SBATCH --partition=day
#SBATCH --array=1-12
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=4:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage11_%A_%a.out

module load Stata/19
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply

# Stata -b names its log after the do-file; give each array task its own
# copy so concurrent tasks don't clobber one another's batch log.
TASK_DO="code/hpc/stage11_task${SLURM_ARRAY_TASK_ID}.do"
cp code/hpc/stage11_inference_dump.do "$TASK_DO"
stata-mp -b do "$TASK_DO"
tail -5 "stage11_task${SLURM_ARRAY_TASK_ID}.log"
grep -q "STAGE 11 TASK ${SLURM_ARRAY_TASK_ID} COMPLETE" \
    "stage11_task${SLURM_ARRAY_TASK_ID}.log" \
    || { echo "STAGE 11 TASK ${SLURM_ARRAY_TASK_ID} FAILED"; exit 1; }
rm -f "$TASK_DO" "stage11_task${SLURM_ARRAY_TASK_ID}.log"
