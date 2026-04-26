#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/12_fit_k13a_grid.R
# Purpose: Fit all cells of the K13-A grid with GHK and GQT (Day 4).
#
# Input:   data/generated/K13A-GRID/<scenario_id>.rds  (18 files)
# Output:  data/fits/K13A-GRID/<scenario_id>.rds       (18 files)
#
# Total: 18 cells x 200 reps x 2 methods = 7200 fits.
# Expected runtime: 1-2 hours on a single Hopper core.
#
# Mirrors 10_fit_k13a.R but with extra progress logging since the run
# is long enough that seeing ETAs matters.
#
# USAGE:
#   Rscript code/scripts/12_fit_k13a_grid.R
#   sbatch code/slurm/12_fit_k13a_grid.slurm
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


DATASET_ID  <- "K13A-GRID"
all_scen    <- list_scenarios(DATASET_ID, dir = DATA_DIR)

if (length(all_scen) == 0L) {
  stop(sprintf(
    "No K13A-GRID scenarios found under %s. Run 04_gen_k13a_grid.R first.",
    file.path(DATA_DIR, DATASET_ID)
  ))
}

# CLI filter
args <- commandArgs(trailingOnly = TRUE)
scenarios_to_fit <- if (length(args) == 0L) {
  all_scen
} else {
  unknown <- setdiff(args, all_scen)
  if (length(unknown) > 0L) {
    stop(sprintf("Unknown scenario(s): %s", paste(unknown, collapse = ", ")))
  }
  args
}


# =====================================================================
# Main
# =====================================================================

log_rule("K13A-GRID fitting: start")
log_info("R version:       %s", R.version.string)
log_info("gcKrig version:  %s", packageVersion("gcKrig"))
log_info("Project root:    %s", PROJECT_ROOT)
log_info("Cells to fit:    %d", length(scenarios_to_fit))

slurm_job <- Sys.getenv("SLURM_JOB_ID", unset = "")
if (nzchar(slurm_job)) {
  log_info("Slurm job id:    %s", slurm_job)
}


t_start <- Sys.time()

for (i in seq_along(scenarios_to_fit)) {

  scen_id <- scenarios_to_fit[[i]]

  # --- ETA based on time so far --------------------------------------
  if (i > 1) {
    elapsed_min   <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
    avg_per_cell  <- elapsed_min / (i - 1)
    remaining_min <- avg_per_cell * (length(scenarios_to_fit) - i + 1)
    log_rule(sprintf("Cell %d/%d: %s   (ETA %.1f min)",
                     i, length(scenarios_to_fit), scen_id, remaining_min))
  } else {
    log_rule(sprintf("Cell %d/%d: %s   (first cell, no ETA yet)",
                     i, length(scenarios_to_fit), scen_id))
  }

  scenario <- load_scenario(DATASET_ID, scen_id, dir = DATA_DIR)
  log_info("  loaded: n=%d  sim_n=%d  lambda=%g  range=%g",
           nrow(scenario$locations),
           ncol(scenario$values),
           scenario$config$marginal$lambda,
           scenario$config$corr$range)

  fit_result <- fit_scenario(
    scenario = scenario,
    methods  = c("GHK", "GQT")
  )

  out_path <- save_fit_result(fit_result, dir = FITS_DIR)

  # --- Cell summary --------------------------------------------------
  res <- fit_result$results
  log_info("  cell done: %d/%d converged",
           sum(res$converged), nrow(res))
  for (m in unique(res$method)) {
    sub_ok <- res[res$method == m & res$converged, ]
    if (nrow(sub_ok) > 0) {
      log_info("    %s: mean=%.3f sec  total=%.1f sec",
               m, mean(sub_ok$runtime_sec), sum(sub_ok$runtime_sec))
    }
  }
}

dt_min <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
log_rule(sprintf("K13A-GRID fitting: done  (%.1f min total)", dt_min))
