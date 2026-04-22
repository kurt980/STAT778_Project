#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/11_fit_misspec.R
# Purpose: Run the Day-3 misspecification study (2x2 matrix).
#
# For each generating scenario (pois_pilot, nbin_pilot), fit with
# both Poisson and negbin marginals. Two of the four cells are
# well-specified; two are misspecified.
#
# Output files:
#   data/fits/MISSPEC/pois_pilot.rds                  (well-specified)
#   data/fits/MISSPEC/pois_pilot__misfit_negbin.rds   (misspecified)
#   data/fits/MISSPEC/nbin_pilot.rds                  (well-specified)
#   data/fits/MISSPEC/nbin_pilot__misfit_poisson.rds  (misspecified)
#
# The suffix __misfit_<family> is produced automatically by
# save_fit_result() when fit_result$misspecified is TRUE.
#
# USAGE:
#   Rscript code/scripts/11_fit_misspec.R
#   sbatch code/slurm/11_fit_misspec.slurm
# =====================================================================

suppressPackageStartupMessages({
  library(gcKrig)
})


.resolve_project_root <- function() {
  p <- Sys.getenv("GCKRIG_PROJECT_ROOT", unset = "")
  if (nzchar(p)) return(p)
  p <- Sys.getenv("SLURM_SUBMIT_DIR", unset = "")
  if (nzchar(p)) return(p)
  getwd()
}

PROJECT_ROOT <- .resolve_project_root()
CODE_DIR     <- file.path(PROJECT_ROOT, "code")
R_DIR        <- file.path(CODE_DIR, "R")
DATA_DIR     <- file.path(PROJECT_ROOT, "data", "generated")
FITS_DIR     <- file.path(PROJECT_ROOT, "data", "fits")


source(file.path(R_DIR, "logging.R"))
source(file.path(R_DIR, "io.R"))
source(file.path(R_DIR, "fit_core.R"))


# =====================================================================
# The 2x2 study matrix
# =====================================================================
# Each row: generating scenario's ID, and the fitting marginal spec
# to use. When the fitting spec's family equals the generating
# scenario's family, the cell is well-specified; otherwise it's
# misspecified. is_misspecified() handles the detection automatically.
#
# For the misspecified fits, we only specify family (gcKrig estimates
# the parameter values). This is deliberate: the user of a real
# dataset would not know the true distribution, only which family
# they're assuming.

DATASET_ID <- "MISSPEC"

STUDY_CELLS <- list(
  # Generate Poisson -> fit Poisson (well-specified)
  list(gen_scen_id = "pois_pilot",
       fit_marginal_spec = NULL),      # NULL = use generating spec

  # Generate Poisson -> fit negbin (misspecified)
  list(gen_scen_id = "pois_pilot",
       fit_marginal_spec = list(family = "negbin", link = "log")),

  # Generate negbin -> fit negbin (well-specified)
  list(gen_scen_id = "nbin_pilot",
       fit_marginal_spec = NULL),

  # Generate negbin -> fit Poisson (misspecified)
  list(gen_scen_id = "nbin_pilot",
       fit_marginal_spec = list(family = "poisson", link = "log"))
)


# =====================================================================
# Main
# =====================================================================

log_rule("MISSPEC fitting: start")
log_info("R version:       %s", R.version.string)
log_info("gcKrig version:  %s", packageVersion("gcKrig"))
log_info("Study cells:     %d", length(STUDY_CELLS))

slurm_job <- Sys.getenv("SLURM_JOB_ID", unset = "")
if (nzchar(slurm_job)) {
  log_info("Slurm job id:    %s", slurm_job)
}


for (i in seq_along(STUDY_CELLS)) {

  cell      <- STUDY_CELLS[[i]]
  gen_scen  <- cell$gen_scen_id
  fit_spec  <- cell$fit_marginal_spec

  log_rule(sprintf("Cell %d/%d: gen=%s  fit=%s",
                   i, length(STUDY_CELLS),
                   gen_scen,
                   if (is.null(fit_spec)) "(well-specified)" else fit_spec$family))

  log_info("Loading scenario...")
  scenario <- load_scenario(DATASET_ID, gen_scen, dir = DATA_DIR)

  log_info("Fitting...")
  fit_result <- fit_scenario(
    scenario          = scenario,
    methods           = c("GHK", "GQT"),
    fit_marginal_spec = fit_spec
  )

  log_info("Saving...")
  out_path <- save_fit_result(fit_result, dir = FITS_DIR)

  # --- Per-cell summary -------------------------------------------
  res <- fit_result$results
  log_info("--- Cell summary ---")
  log_info("Output:       %s", out_path)
  log_info("Misspecified: %s", fit_result$misspecified)
  log_info("Total fits:   %d", nrow(res))
  log_info("Converged:    %d / %d", sum(res$converged), nrow(res))
  for (m in unique(res$method)) {
    sub_ok <- res[res$method == m & res$converged, ]
    if (nrow(sub_ok) > 0) {
      log_info("  %s: mean runtime=%.2f sec  total=%.1f sec",
               m, mean(sub_ok$runtime_sec), sum(sub_ok$runtime_sec))
    }
  }
}

log_rule("MISSPEC fitting: done")
