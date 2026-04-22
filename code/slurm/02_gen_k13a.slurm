#!/bin/bash
# =====================================================================
# File:    code/slurm/02_gen_k13a.slurm
# Purpose: Submit K13-A generation job to Slurm on Hopper.
#
# Usage:
#   sbatch code/slurm/02_gen_k13a.slurm
#   sbatch --export=ALL,SCENARIO_IDS="default" code/slurm/02_gen_k13a.slurm
# =====================================================================
#SBATCH --job-name=gen_k13a
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
echo "Job:           ${SLURM_JOB_NAME} (${SLURM_JOB_ID})"
echo "Started:       $(date -Iseconds)"
echo "Project root:  ${PROJECT_ROOT}"
echo "Node:          $(hostname)"
echo "Rscript:       $(which Rscript)"

Rscript -e 'cat("R.home() = ", R.home(), "\n", sep = "")'
Rscript -e 'cat("R.version.string = ", R.version.string, "\n", sep = "")'
Rscript -e 'cat(".libPaths() =\n"); print(.libPaths())'
echo "==================================================================="

if [[ -n "${SCENARIO_IDS:-}" ]]; then
    echo "Filtering to scenarios: ${SCENARIO_IDS}"
    Rscript code/scripts/02_gen_k13a.R ${SCENARIO_IDS}
else
    Rscript code/scripts/02_gen_k13a.R
fi
echo "==================================================================="
echo "Job ${SLURM_JOB_ID} finished at $(date -Iseconds)"
echo "==================================================================="