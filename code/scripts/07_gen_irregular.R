#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/07_gen_irregular.R
# Purpose: Generate 3 layouts (grid, random, clustered) under the
#          same Poisson(5) + range=0.3 generating model.
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
source(file.path(CONFIG_DIR, "irregular.R"))


build_marginal <- function(marg_spec, locations) {
  if (marg_spec$family == "poisson") {
    return(poisson.gc(lambda = marg_spec$lambda))
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
  list(lambda = spec$marginal$lambda,
       range  = spec$corr$range,
       kappa  = spec$corr$kappa,
       nugget = spec$corr$nugget)
}


# --- Main ----------------------------------------------------------

log_rule("IRREGULAR generation: start")
log_info("R version:       %s", R.version.string)
log_info("gcKrig version:  %s", packageVersion("gcKrig"))
log_info("Scenarios:       %d", length(IRREGULAR_SCENARIOS))

for (scen_id in names(IRREGULAR_SCENARIOS)) {

  spec <- IRREGULAR_SCENARIOS[[scen_id]]
  log_rule(sprintf("Scenario: %s / %s  layout=%s",
                   spec$dataset_id, scen_id, spec$layout$layout_type))

  locs <- do.call(make_locations, spec$layout)
  log_info("  n_locations = %d", nrow(locs))
  log_info("  x range [%.3f, %.3f]", min(locs[,1]), max(locs[,1]))
  log_info("  y range [%.3f, %.3f]", min(locs[,2]), max(locs[,2]))

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
  log_info("  wrote %s", out_path)
}

log_rule("IRREGULAR generation: done")
