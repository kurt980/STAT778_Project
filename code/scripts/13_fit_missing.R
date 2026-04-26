#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/13_fit_missing.R
# Purpose: Fit each missingness scenario with GHK and GQT.
#
# The fitter handles NAs transparently via .fit_one(). Running this
# script looks identical to fitting any other scenario.
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


DATASET_ID  <- "MISSING"
all_scen    <- list_scenarios(DATASET_ID, dir = DATA_DIR)

if (length(all_scen) == 0L) {
  stop("No MISSING scenarios found. Run 05_gen_missing.R first.")
}

args <- commandArgs(trailingOnly = TRUE)
scenarios_to_fit <- if (length(args) == 0L) all_scen else {
  unknown <- setdiff(args, all_scen)
  if (length(unknown) > 0L) {
    stop(sprintf("Unknown scenario(s): %s", paste(unknown, collapse = ", ")))
  }
  args
}


# --- Main ----------------------------------------------------------

log_rule("MISSING fitting: start")
log_info("R version:       %s", R.version.string)
log_info("gcKrig version:  %s", packageVersion("gcKrig"))
log_info("Scenarios:       %d (%s)",
         length(scenarios_to_fit), paste(scenarios_to_fit, collapse = ", "))


t_start <- Sys.time()

for (scen_id in scenarios_to_fit) {

  log_rule(sprintf("Scenario: %s / %s", DATASET_ID, scen_id))

  scenario <- load_scenario(DATASET_ID, scen_id, dir = DATA_DIR)
  log_info("Loaded: n=%d  sim_n=%d  NA frac=%.3f",
           nrow(scenario$locations),
           ncol(scenario$values),
           mean(is.na(scenario$values)))

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
      log_info("  %s: mean runtime=%.2f  mean n_used=%.1f",
               m, mean(sub_ok$runtime_sec), mean(sub_ok$n_used))
    }
  }
}

dt_min <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
log_rule(sprintf("MISSING fitting: done  (%.1f min total)", dt_min))
