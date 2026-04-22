#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/10_fit_k13a.R
# Purpose: Fit every replicate of each K13-A scenario with GHK and GQT.
#
# USAGE (from repo root):
#   Rscript code/scripts/10_fit_k13a.R
#   Rscript code/scripts/10_fit_k13a.R default
#
#   Under Slurm:
#   sbatch code/slurm/10_fit_k13a.slurm
#
# Input:   data/generated/K13-A/<scenario_id>.rds
#          (must already be generated via 02_gen_k13a.R)
# Output:  data/fits/K13-A/<scenario_id>.rds
#
# This is the fitting half of the pipeline. It depends on fit_core.R,
# which in turn delegates all statistical work to gcKrig::mlegc().
# =====================================================================

suppressPackageStartupMessages({
  library(gcKrig)
})


# --- Project root resolution ----------------------------------------
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


# --- Load library ---------------------------------------------------
source(file.path(R_DIR, "logging.R"))
source(file.path(R_DIR, "io.R"))
source(file.path(R_DIR, "fit_core.R"))


# --- Discover scenarios to fit --------------------------------------
DATASET_ID  <- "K13-A"
all_scen    <- list_scenarios(DATASET_ID, dir = DATA_DIR)

if (length(all_scen) == 0L) {
  stop(sprintf(
    "No scenarios found under %s. Run `Rscript code/scripts/02_gen_k13a.R` first.",
    file.path(DATA_DIR, DATASET_ID)
  ))
}

# CLI filter, same convention as the generation scripts.
args <- commandArgs(trailingOnly = TRUE)
scenarios_to_fit <- if (length(args) == 0L) {
  all_scen
} else {
  unknown <- setdiff(args, all_scen)
  if (length(unknown) > 0L) {
    stop(sprintf("Unknown scenario(s): %s. Available: %s",
                 paste(unknown,  collapse = ", "),
                 paste(all_scen, collapse = ", ")))
  }
  args
}


# =====================================================================
# Main
# =====================================================================

log_rule("K13-A fitting: start")
log_info("R version:       %s", R.version.string)
log_info("gcKrig version:  %s", packageVersion("gcKrig"))
log_info("Project root:    %s", PROJECT_ROOT)
log_info("Scenarios input: %s", file.path(DATA_DIR, DATASET_ID))
log_info("Fits output:     %s", file.path(FITS_DIR, DATASET_ID))
log_info("Scenarios to fit: %d  (%s)",
         length(scenarios_to_fit),
         paste(scenarios_to_fit, collapse = ", "))

slurm_job <- Sys.getenv("SLURM_JOB_ID", unset = "")
if (nzchar(slurm_job)) {
  log_info("Slurm job id:    %s", slurm_job)
}


for (scen_id in scenarios_to_fit) {

  log_rule(sprintf("Scenario: %s / %s", DATASET_ID, scen_id))

  log_info("Loading scenario...")
  scenario <- load_scenario(DATASET_ID, scen_id, dir = DATA_DIR)
  log_info("  n_locations = %d, sim_n = %d",
           nrow(scenario$locations), ncol(scenario$values))

  # Do the fits. Both methods, all replicates.
  log_info("Fitting...")
  fit_result <- fit_scenario(
    scenario = scenario,
    methods  = c("GHK", "GQT")
  )

  log_info("Saving fit results...")
  out_path <- save_fit_result(fit_result, dir = FITS_DIR)

  # --- Post-fit summary -----------------------------------------------
  res <- fit_result$results
  log_info("--- Fit summary for %s ---", scen_id)
  log_info("Output file:  %s", out_path)
  log_info("Total fits:   %d", nrow(res))
  log_info("Converged:    %d / %d", sum(res$converged), nrow(res))

  for (m in unique(res$method)) {
    sub_ok <- res[res$method == m & res$converged, ]
    if (nrow(sub_ok) > 0) {
      log_info("  %s: mean runtime=%.2f sec  median=%.2f  total=%.1f sec",
               m, mean(sub_ok$runtime_sec),
               stats::median(sub_ok$runtime_sec),
               sum(sub_ok$runtime_sec))
    } else {
      log_warn("  %s: no successful fits", m)
    }
  }
}

log_rule("K13-A fitting: done")
