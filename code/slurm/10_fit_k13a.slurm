#!/bin/bash
# =====================================================================
# File:    code/slurm/10_fit_k13a.slurm
# Purpose: Submit K13-A fitting job to Slurm on Hopper.
#
# Usage (from repo root):
#   sbatch code/slurm/10_fit_k13a.slurm
#
# Note: GHK is slow. Paper reports ~320 sec/fit at n=49.
#   For sim_n=30 with GHK+GQT, expect up to ~3 hours worst case,
#   typically well under. Time wall below gives comfortable margin.
# =====================================================================

#SBATCH --job-name=fit_k13a
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err
#SBATCH --time=06:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --ntasks=1

set -euo pipefail

export GCKRIG_PROJECT_ROOT="${SLURM_SUBMIT_DIR:-$(pwd)}"
cd "$GCKRIG_PROJECT_ROOT"

mkdir -p logs data/fits

source code/slurm/_env.sh

echo "==================================================================="
echo "Job:           ${SLURM_JOB_NAME} (${SLURM_JOB_ID})"
echo "Submitted:     $(date -Iseconds)"
echo "Project root:  ${GCKRIG_PROJECT_ROOT}"
echo "Node:          $(hostname)"
echo "==================================================================="

if [[ -n "${SCENARIO_IDS:-}" ]]; then
    echo "Filtering to scenarios: ${SCENARIO_IDS}"
    Rscript code/scripts/10_fit_k13a.R ${SCENARIO_IDS}
else
    Rscript code/scripts/10_fit_k13a.R
fi

echo "==================================================================="
echo "Job ${SLURM_JOB_ID} finished at $(date -Iseconds)"
echo "==================================================================="
