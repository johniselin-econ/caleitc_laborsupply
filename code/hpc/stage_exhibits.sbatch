#!/bin/bash
#SBATCH --job-name=caleitc_exhibits
#SBATCH --partition=day
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=1:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_exhibits_%j.out

# Final stage of a full re-run (submitted by run_pipeline.sh with
# --dependency=afterok on all compute stages). Stages the fresh data/tmp
# outputs into results/ (stage_rerun.R), rebuilds every paper table/figure
# from them (00_run_all.R -> latest_result picks the fresh files), and
# compiles the paper. 60_state_tab already wrote its exhibit during its own
# compute job.
module load R/4.4.2-gfbf-2024a
module load texlive/20240312-GCC-13.3.0
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/hpc/stage_rerun.R
Rscript code/00_run_all.R
bash paper/build.sh
