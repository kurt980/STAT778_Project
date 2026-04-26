#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/06_gen_zip.R
# Purpose: Generate ZIP scenarios at three zero-inflation levels.
#
# IMPORTANT NOTE ON gcKrig ZIP PARAMETERIZATION:
# I'm assuming gcKrig's zip.gc() takes a `lambda` parameter for the
# Poisson component and an `od` (or similar) parameter for the
# zero-inflation probability. If smoke testing reveals a different
# parameterization, fix build_marginal() below accordingly. Check
# ?gcKrig::zip.gc in R for the canonical signature.
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
source(file.path(CONFIG_DIR, "zip.R"))


build_marginal <- function(marg_spec, locations) {
  if (marg_spec$family == "zip") {
    # ZIP: gcKrig uses mu for the mean parameter and od for
    # the zero-inflation parameter.
    return(zip.gc(mu = marg_spec$mu, od = marg_spec$od))
  }
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
  tp <- list(range = spec$corr$range, kappa = spec$corr$kappa,
             nugget = spec$corr$nugget)
  if (spec$marginal$family == "zip") {
    tp$mu <- spec$marginal$mu
    tp$p0 <- spec$marginal$od
  }
  tp
}


# --- Main ----------------------------------------------------------

log_rule("ZIP generation: start")
log_info("R version:       %s", R.version.string)
log_info("gcKrig version:  %s", packageVersion("gcKrig"))
log_info("Scenarios:       %d", length(ZIP_SCENARIOS))

for (scen_id in names(ZIP_SCENARIOS)) {

  spec <- ZIP_SCENARIOS[[scen_id]]
  log_rule(sprintf("Scenario: %s / %s", spec$dataset_id, scen_id))
  log_info("  p0 = %.2f, mu = %g", spec$marginal$od, spec$marginal$mu)

  locs <- do.call(make_locations, spec$layout)
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

  log_info("--- Summary ---")
  log_info("Output:       %s", out_path)
  log_info("values dims:  %d x %d", nrow(scenario$values), ncol(scenario$values))
  log_info("value mean:   %.3f", mean(scenario$values))
  log_info("value var:    %.3f", var(as.vector(scenario$values)))
  log_info("zero count:   %d / %d (%.1f%%)",
           sum(scenario$values == 0), length(scenario$values),
           100 * mean(scenario$values == 0))
}

log_rule("ZIP generation: done")
