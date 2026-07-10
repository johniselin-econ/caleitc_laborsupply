#!/bin/bash
#SBATCH --job-name=caleitc_s12appE
#SBATCH --partition=day
#SBATCH --array=1-12
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=23:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage12_%A_%a.out

# Full Appendix E battery in R, one (outcome x spec) task per array element.
# Run only after stage11_det_validate passes (deterministic layers validated).
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/20_altinference.R
