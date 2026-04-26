#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/04_gen_k13a_grid.R
# Purpose: Generate the 18 cells of the K13-A grid study (Day 4).
#
# Mirrors 02_gen_k13a.R but sources the grid config and iterates
# over 18 scenarios instead of 1.
#
# USAGE:
#   Rscript code/scripts/04_gen_k13a_grid.R
#   sbatch code/slurm/04_gen_k13a_grid.slurm
#
# Output:   data/generated/K13A-GRID/<scenario_id>.rds  (18 files)
# Runtime:  simgc is very fast; all 18 cells finish in under a minute.
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
CONFIG_DIR   <- file.path(CODE_DIR, "configs")
DATA_DIR     <- file.path(PROJECT_ROOT, "data", "generated")


source(file.path(R_DIR,      "logging.R"))
source(file.path(R_DIR,      "grids.R"))
source(file.path(R_DIR,      "spec_utils.R"))
source(file.path(R_DIR,      "sim_core.R"))
source(file.path(R_DIR,      "io.R"))
source(file.path(CONFIG_DIR, "k13a_grid.R"))


build_marginal <- function(marg_spec, locations) {
  if (marg_spec$family == "poisson") {
    lam <- marg_spec$lambda
    stopifnot(is.numeric(lam), all(lam > 0))
    return(poisson.gc(lambda = lam))
  }
  stop(sprintf("build_marginal: family '%s' not supported", marg_spec$family))
}

build_corr <- function(corr_spec) {
  if (corr_spec$family == "matern") {
    return(matern.gc(range  = corr_spec$range,
                     kappa  = corr_spec$kappa,
                     nugget = corr_spec$nugget))
  }
  stop(sprintf("build_corr: family '%s' not supported", corr_spec$family))
}

extract_true_params <- function(spec) {
  list(
    lambda = spec$marginal$lambda,
    range  = spec$corr$range,
    kappa  = spec$corr$kappa,
    nugget = spec$corr$nugget
  )
}


.parse_scenario_ids <- function(all_ids) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0L) return(all_ids)
  unknown <- setdiff(args, all_ids)
  if (length(unknown) > 0L) {
    stop(sprintf("Unknown scenario_id(s): %s", paste(unknown, collapse = ", ")))
  }
  args
}


# =====================================================================
# Main
# =====================================================================

log_rule("K13A-GRID generation: start")
log_info("R version:       %s", R.version.string)
log_info("gcKrig version:  %s", packageVersion("gcKrig"))
log_info("Project root:    %s", PROJECT_ROOT)

scenario_ids_to_run <- .parse_scenario_ids(names(K13A_GRID_SCENARIOS))
log_info("Total cells:     %d", length(K13A_GRID_SCENARIOS))
log_info("Cells to run:    %d", length(scenario_ids_to_run))


t_start <- Sys.time()

for (scen_id in scenario_ids_to_run) {

  spec <- K13A_GRID_SCENARIOS[[scen_id]]
  log_rule(sprintf("Scenario: %s / %s", spec$dataset_id, scen_id))

  locs <- do.call(make_locations, spec$layout)
  log_info("  n_locations = %d  lambda = %g  range = %g",
           nrow(locs), spec$marginal$lambda, spec$corr$range)

  marginal_obj <- build_marginal(spec$marginal, locs)
  corr_obj     <- build_corr(spec$corr)

  scenario <- simulate_mc_scenario(
    spec        = spec,
    locations   = locs,
    marginal    = marginal_obj,
    corr        = corr_obj,
    true_params = extract_true_params(spec)
  )

  out_path <- save_scenario(scenario, dir = DATA_DIR)
  log_info("  wrote %s  (values %dx%d)",
           out_path, nrow(scenario$values), ncol(scenario$values))
}

dt <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
log_rule(sprintf("K13A-GRID generation: done  (%.1f sec total)", dt))
