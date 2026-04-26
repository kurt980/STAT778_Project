#!/bin/bash
# 3 scenarios x 2 fittings x 200 reps x 2 methods = 2400 fits.
# At ~0.5-1 sec/fit, 20-40 min. 3-hour wall for safety.
#SBATCH --job-name=fit_zip
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
echo "Job: ${SLURM_JOB_NAME} (${SLURM_JOB_ID}) on $(hostname)"
echo "==================================================================="

Rscript code/scripts/14_fit_zip.R

echo "Job ${SLURM_JOB_ID} done at $(date -Iseconds)"
