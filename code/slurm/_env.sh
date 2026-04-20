# =====================================================================
# File:    code/slurm/_env.sh
# Purpose: Shared environment setup for all Slurm jobs.
#
# Sourced at the top of every code/slurm/*.slurm submission script.
#
# NOTE: Update the module commands below to match the module catalog
#       available on your Hopper account. Check with:
#
#           module avail r
#           module spider r
# =====================================================================

module purge 2>/dev/null || true

# Load R. Adjust to whatever your site provides. Typical on GMU Hopper:
#   module load gnu10
#   module load r
# or a versioned form:
#   module load r/4.2.2-gy
#
# Uncomment and edit the line(s) that match your environment:
# module load gnu10
# module load r

# Personal R library (recommended on HPC):
# export R_LIBS_USER="$HOME/R/library"

# Deterministic BLAS threading:
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"
