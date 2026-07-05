#!/bin/bash
#SBATCH --job-name=caleitc_s8sim2
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=4:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage8_sim2_%j.out

module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
# needs acs_2014_clean_r.rds (01_clean_data.R, job 17096067) and BOTH stage8
# golden dumps on disk: sim2_inputs_golden_2014.csv (stage8_sim2dump.do) and
# sim2_txpydata_golden.raw (stage8_txpydump.do)
Rscript code/R/validate/validate_sim2.R
