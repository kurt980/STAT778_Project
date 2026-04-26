#!/bin/bash
# =====================================================================
# File:    code/slurm/13_fit_missing.slurm
#
# Runtime: 5 scenarios x 200 reps x 2 methods = 2000 fits.
# At ~0.5-1 sec/fit, 15-35 min total. 3-hour wall for safety.
# =====================================================================

#SBATCH --job-name=fit_missing
#SBATCH --output=/scratch/cji4/STAT778_Project/logs/%x-%j.out
#SBATCH --error=/scratch/cji4/STAT778_Project/logs/%x-%j.err
#SBATCH --time=03:00:00
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

Rscript code/scripts/13_fit_missing.R

echo "==================================================================="
echo "Job ${SLURM_JOB_ID} finished at $(date -Iseconds)"
echo "==================================================================="
