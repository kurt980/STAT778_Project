#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/01_gen_h18b.R
# Purpose: Generate Dataset H18-B (Han and De Oliveira 2018, Sec. 4.4).
#
# USAGE (always run from the repo root, STAT778_Project/):
#
#   # Command line:
#   cd ~/STAT778_Project
#   Rscript code/scripts/01_gen_h18b.R
#
#   # Only specific scenario(s):
#   Rscript code/scripts/01_gen_h18b.R default
#   Rscript code/scripts/01_gen_h18b.R range_0.5 range_0.7
#
#   # Inside R or Rmd:
#   setwd("~/STAT778_Project")
#   source("code/scripts/01_gen_h18b.R")
#
#   # Under Slurm:
#   sbatch code/slurm/01_gen_h18b.slurm
#
# Project-root resolution (in order of priority):
#   1. $GCKRIG_PROJECT_ROOT   (explicit override, set by Slurm script)
#   2. $SLURM_SUBMIT_DIR      (set automatically by sbatch)
#   3. getwd()                (interactive fallback)
#
# Output:
#   <repo_root>/data/generated/H18-B/<scenario_id>.rds
# =====================================================================

suppressPackageStartupMessages({
  library(gcKrig)
})


# =====================================================================
# Resolve project root (Slurm-aware)
# =====================================================================

.resolve_project_root <- function() {
  p <- Sys.getenv("GCKRIG_PROJECT_ROOT", unset = "")
  if (nzchar(p)) return(p)
  p <- Sys.getenv("SLURM_SUBMIT_DIR", unset = "")
  if (nzchar(p)) return(p)
  getwd()
}

PROJECT_ROOT <- .resolve_project_root()

# Source code lives under code/; outputs go to top-level data/ and logs/.
CODE_DIR    <- file.path(PROJECT_ROOT, "code")
R_DIR       <- file.path(CODE_DIR, "R")
CONFIG_DIR  <- file.path(CODE_DIR, "configs")
DATA_DIR    <- file.path(PROJECT_ROOT, "data", "generated")


# =====================================================================
# Load project code
# =====================================================================
source(file.path(R_DIR,      "logging.R"))
source(file.path(R_DIR,      "grids.R"))
source(file.path(R_DIR,      "spec_utils.R"))
source(file.path(R_DIR,      "sim_core.R"))
source(file.path(R_DIR,      "io.R"))
source(file.path(CONFIG_DIR, "h18b.R"))


# =====================================================================
# Parse CLI arguments
# =====================================================================

.parse_scenario_ids <- function(all_ids) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0L) return(all_ids)

  unknown <- setdiff(args, all_ids)
  if (length(unknown) > 0L) {
    stop(sprintf(
      "Unknown scenario_id(s): %s. Available: %s",
      paste(unknown, collapse = ", "),
      paste(all_ids,  collapse = ", ")
    ))
  }
  args
}


# =====================================================================
# Helpers (local to this script; promote to code/R/ when reused)
# =====================================================================

build_marginal <- function(marg_spec, locations) {
  log_debug("build_marginal: family='%s'", marg_spec$family)

  if (marg_spec$family == "negbin") {
    b <- marg_spec$beta
    stopifnot(length(b) == 3L)
    mu_vec <- exp(b[1] + b[2] * locations[, 1] + b[3] * locations[, 2])
    log_debug(
      "  negbin mu: min=%.3f median=%.3f max=%.3f  od=%g",
      min(mu_vec), stats::median(mu_vec), max(mu_vec), marg_spec$od
    )
    return(negbin.gc(mu = mu_vec, od = marg_spec$od))
  }

  stop(sprintf("build_marginal: family '%s' not yet supported",
               marg_spec$family))
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

  stop(sprintf("build_corr: family '%s' not yet supported",
               corr_spec$family))
}

extract_true_params <- function(spec) {
  tp <- list()
  if (spec$marginal$family == "negbin") {
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

# Uncomment for verbose debug logging:
# options(sim_pipeline.debug = TRUE)

log_rule("H18-B generation: start")
log_info("R version:        %s", R.version.string)
log_info("gcKrig version:   %s", packageVersion("gcKrig"))
log_info("Project root:     %s", PROJECT_ROOT)
log_info("Code dir:         %s", CODE_DIR)
log_info("Data output dir:  %s", DATA_DIR)

slurm_job   <- Sys.getenv("SLURM_JOB_ID",        unset = "")
slurm_array <- Sys.getenv("SLURM_ARRAY_TASK_ID", unset = "")
if (nzchar(slurm_job)) {
  log_info("Slurm job id:     %s%s",
           slurm_job,
           if (nzchar(slurm_array)) sprintf(" (array task %s)", slurm_array) else "")
  log_info("Slurm submit dir: %s", Sys.getenv("SLURM_SUBMIT_DIR"))
  log_info("Node:             %s",
           Sys.getenv("SLURMD_NODENAME", Sys.info()[["nodename"]]))
}

scenario_ids_to_run <- .parse_scenario_ids(names(H18B_SCENARIOS))
log_info("Scenarios to run: %d  (%s)",
         length(scenario_ids_to_run),
         paste(scenario_ids_to_run, collapse = ", "))


for (scen_id in scenario_ids_to_run) {

  spec <- H18B_SCENARIOS[[scen_id]]
  log_rule(sprintf("Scenario: %s / %s", spec$dataset_id, scen_id))

  if (spec$scenario_id != scen_id) {
    log_warn("key/scenario_id mismatch: list key '%s' vs spec '%s'",
             scen_id, spec$scenario_id)
  }

  log_info("Step 1/4: build locations")
  locs <- do.call(make_locations, spec$layout)
  log_info("  n_locations = %d", nrow(locs))
  log_info("  x range = [%.3f, %.3f]", min(locs[, 1]), max(locs[, 1]))
  log_info("  y range = [%.3f, %.3f]", min(locs[, 2]), max(locs[, 2]))

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
  log_info("Output file:       %s", out_path)
  log_info("config round-trip: %d top-level fields preserved",
           length(scenario$config))
  log_info("values dims:       %d x %d",
           nrow(scenario$values), ncol(scenario$values))
  log_info("value range:       [%d, %d]",
           as.integer(min(scenario$values)),
           as.integer(max(scenario$values)))
  log_info("value mean:        %.3f", mean(scenario$values))
  log_info("zero count:        %d / %d",
           sum(scenario$values == 0), length(scenario$values))
}

log_rule("H18-B generation: done")
