# =====================================================================
# File:    code/R/io.R
# Purpose: Save and load scenario objects.
#
# Design notes:
#   - Scenarios are serialized as .rds files.
#   - Directory layout: <dir>/<dataset_id>/<scenario_id>.rds.
#   - Default `dir` is "data/generated", relative to whatever the
#     working directory is at call time. Since all entry points (the
#     script, the Slurm job, the Rmd) set the working directory to
#     the repo root (STAT778_Project/), this resolves to
#     STAT778_Project/data/generated/.
# =====================================================================


#' Save a scenario object to disk as an .rds file.
save_scenario <- function(scenario, dir = "data/generated") {

  stopifnot(
    is.list(scenario),
    !is.null(scenario$dataset_id),  nzchar(scenario$dataset_id),
    !is.null(scenario$scenario_id), nzchar(scenario$scenario_id)
  )

  out_dir  <- file.path(dir, scenario$dataset_id)
  if (!dir.exists(out_dir)) {
    log_debug("save_scenario: creating directory %s", out_dir)
    dir.create(out_dir, recursive = TRUE)
  }

  out_path <- file.path(out_dir, paste0(scenario$scenario_id, ".rds"))

  if (file.exists(out_path)) {
    log_warn("save_scenario: overwriting existing file %s", out_path)
  }

  saveRDS(scenario, file = out_path)

  size_kb <- file.info(out_path)$size / 1024
  log_info("save_scenario: wrote %s (%.1f KB)", out_path, size_kb)

  invisible(out_path)
}


#' Load a scenario by dataset_id and scenario_id.
load_scenario <- function(dataset_id, scenario_id, dir = "data/generated") {

  path <- file.path(dir, dataset_id, paste0(scenario_id, ".rds"))
  if (!file.exists(path)) {
    stop(sprintf("load_scenario: file not found: %s", path))
  }

  log_debug("load_scenario: reading %s", path)
  readRDS(path)
}


#' List all scenarios saved for a given dataset_id.
list_scenarios <- function(dataset_id, dir = "data/generated") {
  d <- file.path(dir, dataset_id)
  if (!dir.exists(d)) return(character(0))
  files <- list.files(d, pattern = "\\.rds$", full.names = FALSE)
  tools::file_path_sans_ext(files)
}
