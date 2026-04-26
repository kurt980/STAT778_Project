#!/usr/bin/env Rscript
# =====================================================================
# Script:  code/scripts/14_fit_zip.R
# Purpose: Fit ZIP scenarios two ways: as ZIP (well-specified when
#          p0 > 0) and as Poisson (misspecified when p0 > 0).
#
# Output files per scenario:
#   data/fits/ZIP/p0_20.rds               <- fit as ZIP
#   data/fits/ZIP/p0_20__misfit_poisson.rds  <- fit as Poisson
#
# The p0_0 scenario is a pure Poisson baseline; fitting it as ZIP is
# still "well-specified" in the sense that ZIP with p0=0 degenerates
# to Poisson, but numerically it may show the boundary-parameter
# symptoms we saw in the misspec study (overdispersion parameter
# pegging at 0).
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


DATASET_ID  <- "ZIP"

all_scen <- list_scenarios(DATASET_ID, dir = DATA_DIR)
if (length(all_scen) == 0L) {
  stop("No ZIP scenarios found. Run 06_gen_zip.R first.")
}

# Study matrix: each scenario x (well-specified ZIP, misspec Poisson).
STUDY_CELLS <- list()
for (sid in all_scen) {
  STUDY_CELLS[[length(STUDY_CELLS) + 1]] <- list(
    gen_scen_id = sid, fit_marginal_spec = NULL)  # as ZIP
  STUDY_CELLS[[length(STUDY_CELLS) + 1]] <- list(
    gen_scen_id = sid,
    fit_marginal_spec = list(family = "poisson"))  # as Poisson
}


# --- Main ----------------------------------------------------------

log_rule("ZIP fitting: start")
log_info("R version:       %s", R.version.string)
log_info("gcKrig version:  %s", packageVersion("gcKrig"))
log_info("Total cells:     %d", length(STUDY_CELLS))


for (i in seq_along(STUDY_CELLS)) {

  cell     <- STUDY_CELLS[[i]]
  gen_scen <- cell$gen_scen_id
  fit_spec <- cell$fit_marginal_spec

  log_rule(sprintf("Cell %d/%d: gen=%s fit=%s",
                   i, length(STUDY_CELLS), gen_scen,
                   if (is.null(fit_spec)) "(ZIP, well-specified)" else "poisson (misspec)"))

  scenario <- load_scenario(DATASET_ID, gen_scen, dir = DATA_DIR)

  fit_result <- fit_scenario(
    scenario          = scenario,
    methods           = c("GHK", "GQT"),
    fit_marginal_spec = fit_spec
  )

  out_path <- save_fit_result(fit_result, dir = FITS_DIR)

  res <- fit_result$results
  log_info("--- Cell summary ---")
  log_info("Output:       %s", out_path)
  log_info("Converged:    %d / %d", sum(res$converged), nrow(res))
  for (m in unique(res$method)) {
    sub_ok <- res[res$method == m & res$converged, ]
    if (nrow(sub_ok) > 0) {
      log_info("  %s: mean runtime=%.2f sec", m, mean(sub_ok$runtime_sec))
    }
  }
}

log_rule("ZIP fitting: done")
