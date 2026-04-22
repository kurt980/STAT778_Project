#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/02_gen_k13a.R
# Purpose: Generate Dataset K13-A (Kazianka 2013, Section 4).
#
# USAGE (from repo root ~/STAT778_Project/):
#   Rscript code/scripts/02_gen_k13a.R
#   Rscript code/scripts/02_gen_k13a.R default
#
#   Under Slurm:
#   sbatch code/slurm/02_gen_k13a.slurm
#
# Output:
#   data/generated/K13-A/<scenario_id>.rds  (one per scenario)
#
# Differs from 01_gen_h18b.R only in:
#   - sources code/configs/k13a.R instead of h18b.R
#   - build_marginal() additionally handles the "poisson" family
#   - extract_true_params() handles the "poisson" family
# =====================================================================

suppressPackageStartupMessages({
  library(gcKrig)
})


# --- Project root resolution (Slurm-aware) --------------------------
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


# --- Load library ---------------------------------------------------
source(file.path(R_DIR,      "logging.R"))
source(file.path(R_DIR,      "grids.R"))
source(file.path(R_DIR,      "spec_utils.R"))
source(file.path(R_DIR,      "sim_core.R"))
source(file.path(R_DIR,      "io.R"))
source(file.path(CONFIG_DIR, "k13a.R"))


# --- CLI scenario filter --------------------------------------------
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
# Helpers
# =====================================================================

build_marginal <- function(marg_spec, locations) {
  log_debug("build_marginal: family='%s'", marg_spec$family)

  if (marg_spec$family == "poisson") {
    # lambda may be a scalar (constant intensity) or a vector (location
    # dependent). K13-A uses a scalar; we support both.
    lam <- marg_spec$lambda
    stopifnot(is.numeric(lam), all(lam > 0))
    log_debug("  poisson lambda: min=%.3f max=%.3f", min(lam), max(lam))
    return(poisson.gc(lambda = lam))
  }

  if (marg_spec$family == "negbin") {
    b <- marg_spec$beta
    stopifnot(length(b) == 3L)
    mu_vec <- exp(b[1] + b[2] * locations[, 1] + b[3] * locations[, 2])
    log_debug("  negbin mu: min=%.3f max=%.3f", min(mu_vec), max(mu_vec))
    return(negbin.gc(mu = mu_vec, od = marg_spec$od))
  }

  stop(sprintf("build_marginal: family '%s' not supported", marg_spec$family))
}


build_corr <- function(corr_spec) {
  log_debug("build_corr: family='%s'", corr_spec$family)

  if (corr_spec$family == "matern") {
    return(matern.gc(
      range  = corr_spec$range,
      kappa  = corr_spec$kappa,
      nugget = corr_spec$nugget
    ))
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


# =====================================================================
# Main
# =====================================================================

log_rule("K13-A generation: start")
log_info("R version:        %s", R.version.string)
log_info("gcKrig version:   %s", packageVersion("gcKrig"))
log_info("Project root:     %s", PROJECT_ROOT)
log_info("Data output dir:  %s", DATA_DIR)

slurm_job <- Sys.getenv("SLURM_JOB_ID", unset = "")
if (nzchar(slurm_job)) {
  log_info("Slurm job id:     %s", slurm_job)
  log_info("Node:             %s", Sys.getenv("SLURMD_NODENAME", Sys.info()[["nodename"]]))
}

scenario_ids_to_run <- .parse_scenario_ids(names(K13A_SCENARIOS))
log_info("Scenarios to run: %d  (%s)",
         length(scenario_ids_to_run),
         paste(scenario_ids_to_run, collapse = ", "))


for (scen_id in scenario_ids_to_run) {

  spec <- K13A_SCENARIOS[[scen_id]]
  log_rule(sprintf("Scenario: %s / %s", spec$dataset_id, scen_id))

  if (spec$scenario_id != scen_id) {
    log_warn("key/scenario_id mismatch: '%s' vs '%s'", scen_id, spec$scenario_id)
  }

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
  log_info("Output file:  %s", out_path)
  log_info("values dims:  %d x %d", nrow(scenario$values), ncol(scenario$values))
  log_info("value range:  [%d, %d]",
           as.integer(min(scenario$values)), as.integer(max(scenario$values)))
  log_info("value mean:   %.3f", mean(scenario$values))
  log_info("zero count:   %d / %d",
           sum(scenario$values == 0), length(scenario$values))
}

log_rule("K13-A generation: done")
