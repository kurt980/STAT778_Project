#!/bin/bash
# =====================================================================
# File:    code/slurm/04_gen_k13a_grid.slurm
# Purpose: Generate the 18-cell K13-A grid on Hopper.
#
# Runtime: simgc is fast; whole grid finishes in under a minute.
# =====================================================================

#SBATCH --job-name=gen_k13a_grid
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

Rscript code/scripts/04_gen_k13a_grid.R

echo "==================================================================="
echo "Job ${SLURM_JOB_ID} finished at $(date -Iseconds)"
echo "==================================================================="
