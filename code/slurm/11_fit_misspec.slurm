#!/bin/bash
# =====================================================================
# File:    code/slurm/11_fit_misspec.slurm
# Purpose: Run the 2x2 misspecification study on Hopper.
#
# Runtime: 4 cells x 30 reps x 2 methods = 240 fits. At GHK ~0.5-2 sec
# per fit on current Hopper hardware, the whole study is well under
# an hour. The 2-hour wall gives margin for slow replicates.
# =====================================================================

#SBATCH --job-name=fit_misspec
#SBATCH --output=/scratch/cji4/STAT778_Project/logs/%x-%j.out
#SBATCH --error=/scratch/cji4/STAT778_Project/logs/%x-%j.err
#SBATCH --time=02:00:00
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
echo "Job:           ${SLURM_JOB_NAME} (${SLURM_JOB_ID})"
echo "Started:       $(date -Iseconds)"
echo "Node:          $(hostname)"
echo "==================================================================="

Rscript code/scripts/11_fit_misspec.R

echo "==================================================================="
echo "Job ${SLURM_JOB_ID} finished at $(date -Iseconds)"
echo "==================================================================="
