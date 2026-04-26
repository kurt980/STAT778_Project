#!/bin/bash
#SBATCH --job-name=gen_zip
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
echo "Job: ${SLURM_JOB_NAME} (${SLURM_JOB_ID}) on $(hostname)"
echo "==================================================================="

Rscript code/scripts/06_gen_zip.R

echo "Job ${SLURM_JOB_ID} done at $(date -Iseconds)"
