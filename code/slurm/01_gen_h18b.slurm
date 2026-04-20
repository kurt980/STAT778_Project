#!/bin/bash
# =====================================================================
# File:    code/slurm/01_gen_h18b.slurm
# Purpose: Submit the H18-B generation job to Slurm on Hopper.
#
# Usage (from repo root ~/STAT778_Project/):
#   sbatch code/slurm/01_gen_h18b.slurm
#
# Optionally, filter to specific scenarios:
#   sbatch --export=ALL,SCENARIO_IDS="default range_0.5" code/slurm/01_gen_h18b.slurm
#
# Output files:
#   logs/gen_h18b-<jobid>.out
#   logs/gen_h18b-<jobid>.err
# =====================================================================

#SBATCH --job-name=gen_h18b
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err
#SBATCH --time=00:30:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --ntasks=1
# #SBATCH --partition=normal
# #SBATCH --mail-type=END,FAIL
# #SBATCH --mail-user=you@example.com

set -euo pipefail

# --- Resolve project root from the submission directory -------------
# sbatch sets $SLURM_SUBMIT_DIR to wherever you submitted from.
# You should submit from STAT778_Project/, so this becomes the repo root.
export GCKRIG_PROJECT_ROOT="${SLURM_SUBMIT_DIR:-$(pwd)}"
cd "$GCKRIG_PROJECT_ROOT"

# --- Ensure required directories exist ------------------------------
mkdir -p logs data/generated

# --- Source shared environment (modules, R_LIBS_USER, etc.) ---------
source code/slurm/_env.sh

# --- Banner ---------------------------------------------------------
echo "==================================================================="
echo "Job:           ${SLURM_JOB_NAME} (${SLURM_JOB_ID})"
echo "Submitted:     $(date -Iseconds)"
echo "Project root:  ${GCKRIG_PROJECT_ROOT}"
echo "Node:          $(hostname)"
echo "Rscript:       $(command -v Rscript)"
echo "==================================================================="

# --- Run the R script -----------------------------------------------
if [[ -n "${SCENARIO_IDS:-}" ]]; then
    echo "Filtering to scenarios: ${SCENARIO_IDS}"
    # shellcheck disable=SC2086
    Rscript code/scripts/01_gen_h18b.R ${SCENARIO_IDS}
else
    Rscript code/scripts/01_gen_h18b.R
fi

echo "==================================================================="
echo "Job ${SLURM_JOB_ID} finished at $(date -Iseconds)"
echo "==================================================================="
