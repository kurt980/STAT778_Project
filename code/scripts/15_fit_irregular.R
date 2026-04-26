#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/15_fit_irregular.R
# Purpose: Fit the 3 irregular-layout scenarios with GHK and GQT.
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


DATASET_ID <- "IRREGULAR"
all_scen   <- list_scenarios(DATASET_ID, dir = DATA_DIR)

if (length(all_scen) == 0L) {
  stop("No IRREGULAR scenarios found. Run 07_gen_irregular.R first.")
}


log_rule("IRREGULAR fitting: start")
log_info("Scenarios:   %d", length(all_scen))


for (scen_id in all_scen) {

  log_rule(sprintf("Scenario: %s / %s", DATASET_ID, scen_id))

  scenario <- load_scenario(DATASET_ID, scen_id, dir = DATA_DIR)
  log_info("  layout: %s  n=%d  sim_n=%d",
           scenario$config$layout$layout_type,
           nrow(scenario$locations),
           ncol(scenario$values))

  fit_result <- fit_scenario(
    scenario = scenario,
    methods  = c("GHK", "GQT")
  )

  out_path <- save_fit_result(fit_result, dir = FITS_DIR)

  res <- fit_result$results
  log_info("--- Cell summary ---")
  log_info("Output:     %s", out_path)
  log_info("Converged:  %d / %d", sum(res$converged), nrow(res))
  for (m in unique(res$method)) {
    sub_ok <- res[res$method == m & res$converged, ]
    if (nrow(sub_ok) > 0) {
      log_info("  %s: mean runtime=%.2f sec", m, mean(sub_ok$runtime_sec))
    }
  }
}

log_rule("IRREGULAR fitting: done")
