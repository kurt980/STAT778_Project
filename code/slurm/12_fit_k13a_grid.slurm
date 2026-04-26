#!/bin/bash
# =====================================================================
# File:    code/slurm/12_fit_k13a_grid.slurm
# Purpose: Fit the 18-cell K13-A grid with GHK and GQT on Hopper.
#
# Runtime estimate:
#   - 18 cells x 200 reps x 2 methods = 7200 fits
#   - At ~0.5-1 sec/fit (K13-A pilot figures) = 60-120 min
#   - Larger n=49 cells will be slower than n=25 cells
#
# Time wall set to 12 hours to accommodate slow cells and Hopper load
# variability. Actual runtime almost certainly under 3 hours.
# =====================================================================

#SBATCH --job-name=fit_k13a_grid
#SBATCH --output=/scratch/cji4/STAT778_Project/logs/%x-%j.out
#SBATCH --error=/scratch/cji4/STAT778_Project/logs/%x-%j.err
#SBATCH --time=12:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --ntasks=1

set -euo pipefail

PROJECT_ROOT="/scratch/cji4/STAT778_Project"
mkdir -p "${PROJECT_ROOT}/logs" "${PROJECT_ROOT}/data/fits"
source "${PROJECT_ROOT}/code/slurm/_env.sh"
cd "${PROJECT_ROOT}" || exit 1

echo "==================================================================="
echo "Job:      ${SLURM_JOB_NAME} (${SLURM_JOB_ID})"
echo "Started:  $(date -Iseconds)"
echo "Node:     $(hostname)"
echo "==================================================================="

Rscript code/scripts/12_fit_k13a_grid.R

echo "==================================================================="
echo "Job ${SLURM_JOB_ID} finished at $(date -Iseconds)"
echo "==================================================================="
