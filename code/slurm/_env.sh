# =====================================================================
# File:    code/slurm/_env.sh
# Purpose: Shared environment setup for all Slurm jobs.
#
# Sourced by every code/slurm/*.slurm submission script.
# =====================================================================

module purge 2>/dev/null || true

# R toolchain on Hopper. Keep gnu10 + r/4.3.1-gnu-openblas paired
# together — this is the combination under which gcKrig is installed
# in renv/library/R-4.3/.
module load gnu10
module load r/4.3.1-gnu-openblas

# Deterministic threading. The project pipeline uses R-level
# parallelism (snowfall, etc.); leaving BLAS single-threaded
# prevents oversubscription and reduces run-to-run variability.
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"