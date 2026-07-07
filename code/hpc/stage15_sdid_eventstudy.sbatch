#!/bin/bash
#SBATCH --job-name=caleitc_s15sdides
#SBATCH --partition=day
#SBATCH --array=1-12
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=6:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage15_%A_%a.out

# Weighted SDID event studies (Ciccia decomposition) for the Table 2
# headline fits (Phase 3). One (outcome x spec) cell per array task; each
# writes data/tmp/sdid_county_es_r_task<k>.{csv,rds} incl. the bootstrap
# replication matrix for later HonestDiD use. Cov-spec bootstraps redo the
# fork's joint-beta optimization per replicate (~1.5-2h); no-cov tasks
# finish in minutes.
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/R/03c_sdid_eventstudy.R
