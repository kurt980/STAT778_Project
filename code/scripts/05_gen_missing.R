#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/05_gen_missing.R
# Purpose: Generate scenarios with varying MCAR missingness rates.
#
# For each rate in MISSING_SCENARIOS:
#   1. Simulate the base Poisson scenario (same underlying data every
#      time, thanks to shared seed).
#   2. Apply apply_mcar() with the specified rate.
#   3. Save.
#
# The rate=0 case skips the masking step and saves as-is; it's the
# baseline that should match K13-A default in statistics.
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
source(file.path(R_DIR,      "missingness.R"))
source(file.path(CONFIG_DIR, "missing.R"))


# --- Local helpers --------------------------------------------------

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
  list(lambda = spec$marginal$lambda,
       range  = spec$corr$range,
       kappa  = spec$corr$kappa,
       nugget = spec$corr$nugget)
}


# --- Main ----------------------------------------------------------

log_rule("MISSING generation: start")
log_info("R version:       %s", R.version.string)
log_info("gcKrig version:  %s", packageVersion("gcKrig"))
log_info("Scenarios:       %d", length(MISSING_SCENARIOS))

for (scen_id in names(MISSING_SCENARIOS)) {

  spec <- MISSING_SCENARIOS[[scen_id]]
  log_rule(sprintf("Scenario: %s / %s", spec$dataset_id, scen_id))
  log_info("  missing_rate: %.2f", spec$missing_rate)

  # Step 1-3: build locations, gcKrig objects, simulate.
  locs         <- do.call(make_locations, spec$layout)
  marginal_obj <- build_marginal(spec$marginal, locs)
  corr_obj     <- build_corr(spec$corr)

  scenario <- simulate_mc_scenario(
    spec        = spec,
    locations   = locs,
    marginal    = marginal_obj,
    corr        = corr_obj,
    true_params = extract_true_params(spec)
  )

  # Step 4: apply missingness (skip if rate=0).
  if (spec$missing_rate > 0) {
    log_info("Applying MCAR at rate %.2f", spec$missing_rate)
    scenario <- apply_mcar(scenario, missing_rate = spec$missing_rate)
  } else {
    log_info("rate=0; no masking applied")
  }

  # Step 5: save.
  out_path <- save_scenario(scenario, dir = DATA_DIR)

  log_info("--- Summary ---")
  log_info("Output:       %s", out_path)
  log_info("values dims:  %d x %d", nrow(scenario$values), ncol(scenario$values))
  log_info("NA fraction:  %.3f", mean(is.na(scenario$values)))
  if (!is.null(scenario$values_full)) {
    log_info("original preserved in $values_full (dims %d x %d)",
             nrow(scenario$values_full), ncol(scenario$values_full))
  }
}

log_rule("MISSING generation: done")
