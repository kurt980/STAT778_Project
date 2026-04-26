#!/bin/bash
# =====================================================================
# File:    code/slurm/05_gen_missing.slurm
# =====================================================================

#SBATCH --job-name=gen_missing
#SBATCH --output=/scratch/cji4/STAT778_Project/logs/%x-%j.out
#SBATCH --error=/scratch/cji4/STAT778_Project/logs/%x-%j.err
#SBATCH --time=00:30:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --ntasks=1

set -euo pipefail

PROJECT_ROOT="/scratch/cji4/STAT778_Project"
mkdir -p "${PROJECT_ROOT}/logs" "${PROJECT_ROOT}/data/generated"
source "${PROJECT_ROOT}/code/slurm/_env.sh"
cd "${PROJECT_ROOT}" || exit 1

echo "==================================================================="
echo "Job:      ${SLURM_JOB_NAME} (${SLURM_JOB_ID})"
echo "Started:  $(date -Iseconds)"
echo "Node:     $(hostname)"
echo "==================================================================="

Rscript code/scripts/05_gen_missing.R

echo "==================================================================="
echo "Job ${SLURM_JOB_ID} finished at $(date -Iseconds)"
echo "==================================================================="
