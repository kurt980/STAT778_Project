#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/03_gen_misspec.R
# Purpose: Generate data for the misspecification study (Day 3).
#
# Produces two scenarios under dataset_id "MISSPEC":
#   pois_pilot  - Poisson(5) on 7x7, 30 reps
#   nbin_pilot  - NegBin(mean=5, od=1) on 7x7, 30 reps
#
# Both use identical spatial structure (correlation range 0.3, no nugget)
# so the downstream misspecification analysis isolates the effect of the
# marginal choice.
#
# USAGE (from repo root):
#   Rscript code/scripts/03_gen_misspec.R
#
#   Under Slurm:
#   sbatch code/slurm/03_gen_misspec.slurm
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
source(file.path(CONFIG_DIR, "misspec.R"))


# --- Build helpers --------------------------------------------------
# Same pattern as 02_gen_k13a.R; local to this script until the
# copy-paste count makes it worth promoting.

build_marginal <- function(marg_spec, locations) {
  if (marg_spec$family == "poisson") {
    lam <- marg_spec$lambda
    stopifnot(is.numeric(lam), all(lam > 0))
    return(poisson.gc(lambda = lam))
  }
  if (marg_spec$family == "negbin") {
    b <- marg_spec$beta
    stopifnot(length(b) == 3L)
    mu_vec <- exp(b[1] + b[2] * locations[, 1] + b[3] * locations[, 2])
    return(negbin.gc(mu = mu_vec, od = marg_spec$od))
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
  tp <- list()
  if (spec$marginal$family == "poisson") {
    tp$lambda <- spec$marginal$lambda
  } else if (spec$marginal$family == "negbin") {
    tp$beta <- spec$marginal$beta
    tp$od   <- spec$marginal$od
  }
  if (spec$corr$family == "matern") {
    tp$range  <- spec$corr$range
    tp$kappa  <- spec$corr$kappa
    tp$nugget <- spec$corr$nugget
  }
  tp
}


# --- CLI filter -----------------------------------------------------
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

log_rule("MISSPEC generation: start")
log_info("R version:       %s", R.version.string)
log_info("gcKrig version:  %s", packageVersion("gcKrig"))
log_info("Project root:    %s", PROJECT_ROOT)
log_info("Data output dir: %s", DATA_DIR)

scenario_ids_to_run <- .parse_scenario_ids(names(MISSPEC_SCENARIOS))
log_info("Scenarios to run: %d  (%s)",
         length(scenario_ids_to_run),
         paste(scenario_ids_to_run, collapse = ", "))


for (scen_id in scenario_ids_to_run) {

  spec <- MISSPEC_SCENARIOS[[scen_id]]
  log_rule(sprintf("Scenario: %s / %s", spec$dataset_id, scen_id))

  log_info("Step 1/4: build locations")
  locs <- do.call(make_locations, spec$layout)
  log_info("  n_locations = %d", nrow(locs))

  log_info("Step 2/4: build gcKrig objects")
  marginal_obj <- build_marginal(spec$marginal, locs)
  corr_obj     <- build_corr(spec$corr)

  log_info("Step 3/4: simulate")
  scenario <- simulate_mc_scenario(
    spec        = spec,
    locations   = locs,
    marginal    = marginal_obj,
    corr        = corr_obj,
    true_params = extract_true_params(spec)
  )

  log_info("Step 4/4: save")
  out_path <- save_scenario(scenario, dir = DATA_DIR)

  log_info("--- Post-generation summary ---")
  log_info("Output file: %s", out_path)
  log_info("values dims: %d x %d", nrow(scenario$values), ncol(scenario$values))
  log_info("value range: [%d, %d]",
           as.integer(min(scenario$values)), as.integer(max(scenario$values)))
  log_info("value mean:  %.3f", mean(scenario$values))
  log_info("value var:   %.3f", var(as.vector(scenario$values)))
  log_info("zero count:  %d / %d",
           sum(scenario$values == 0), length(scenario$values))
}

log_rule("MISSPEC generation: done")
