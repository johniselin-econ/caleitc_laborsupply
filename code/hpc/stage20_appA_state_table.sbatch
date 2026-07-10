#!/bin/bash
#SBATCH --job-name=caleitc_s20statetab
#SBATCH --partition=day
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=1:00:00
#SBATCH --output=/nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply/code/logs/slurm_stage20_%j.out

# Build Appendix Table A.1 (tab_appA_fig1): sample states + population
# statistics. Reconstructed from the paper caption (no legacy producer);
# loads the 2 GB working file, collapses to per-state mean/min/max annual
# population of the baseline sample, flags main/Medicaid/no-EITC pools.
# Run as a batch job because the working-file load exceeds the login-node
# per-session memory cap.
module load R/4.4.2-gfbf-2024a
cd /nfs/roberts/project/pi_nrs36/ji252/repos/caleitc_laborsupply
Rscript code/60_state_tab.R
