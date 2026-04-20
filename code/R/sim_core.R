# =====================================================================
# File:    code/R/sim_core.R
# Purpose: Core simulation utilities.
#
#          make_scenario()         - scenario object factory (schema).
#          simulate_mc_scenario()  - Monte Carlo scenarios (wraps simgc).
#          build_fixed_scenario()  - deterministic scenarios (K13-B/C).
#
# Design notes:
#   - Every scenario (Monte Carlo or fixed) is a list with the same
#     fields. Downstream code consumes any scenario agnostically.
#   - Every saved scenario stores the FULL input spec verbatim in the
#     $config field. No schema migration required when spec fields are
#     added later.
#   - simulate_mc_scenario() takes the spec as its primary argument
#     plus pre-constructed gcKrig S3 objects for the marginal and
#     correlation. The simulator stays ignorant of marginal/correlation
#     families: it never touches spec$marginal or spec$corr.
# =====================================================================


#' Construct a scenario object with the project's standard schema.
make_scenario <- function(config,
                          locations,
                          values,
                          true_params            = NULL,
                          seed_info              = NULL,
                          coord_transform_applied = FALSE,
                          missingness_spec       = NULL,
                          contamination_spec     = NULL) {

  stopifnot(
    is.list(config),
    !is.null(config$dataset_id),  nzchar(config$dataset_id),
    !is.null(config$scenario_id), nzchar(config$scenario_id)
  )

  stopifnot(
    is.matrix(locations), ncol(locations) == 2,
    is.matrix(values),    nrow(values) == nrow(locations)
  )

  list(
    dataset_id  = config$dataset_id,
    scenario_id = config$scenario_id,

    config = config,

    locations = locations,

    values      = values,
    values_full = NULL,

    true_params = true_params,

    created_at     = Sys.time(),
    r_version      = R.version.string,
    gcKrig_version = tryCatch(
      as.character(packageVersion("gcKrig")),
      error = function(e) NA_character_
    ),

    seed_info               = seed_info,
    coord_transform_applied = coord_transform_applied,

    missingness_spec   = missingness_spec,
    contamination_spec = contamination_spec
  )
}


#' Simulate a Monte Carlo scenario from a Gaussian copula model.
simulate_mc_scenario <- function(spec,
                                 locations,
                                 marginal,
                                 corr,
                                 true_params     = NULL,
                                 coord_transform = NULL) {

  stopifnot(
    is.list(spec),
    !is.null(spec$sim_n), is.numeric(spec$sim_n), spec$sim_n >= 1L,
    !is.null(spec$seed),  is.numeric(spec$seed),  length(spec$seed) == 1L,
    is.matrix(locations), ncol(locations) == 2,
    inherits(marginal, "marginal.gc"),
    inherits(corr,     "corr.gc")
  )

  log_info("simulate_mc_scenario: dataset=%s  scenario=%s",
           spec$dataset_id, spec$scenario_id)
  log_info("  n_locations=%d  sim_n=%d  seed=%d",
           nrow(locations), spec$sim_n, spec$seed)

  sim_locs <- locations
  if (!is.null(coord_transform)) {
    stopifnot(is.function(coord_transform))
    sim_locs <- coord_transform(locations)
    stopifnot(
      is.matrix(sim_locs),
      nrow(sim_locs) == nrow(locations),
      ncol(sim_locs) == 2
    )
    log_info("  coord_transform applied: (%.3f, %.3f) -> (%.3f, %.3f)",
             locations[1, 1], locations[1, 2],
             sim_locs[1, 1],  sim_locs[1, 2])
  }

  log_debug("  seeding RNG with seed=%d", spec$seed)
  set.seed(spec$seed)

  log_debug("  calling gcKrig::simgc ...")
  t0 <- Sys.time()
  sim_out <- gcKrig::simgc(
    locs     = sim_locs,
    sim.n    = spec$sim_n,
    marginal = marginal,
    corr     = corr
  )
  dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  log_info("  simgc returned in %.3f sec", dt)

  raw <- sim_out$data
  values <- if (is.matrix(raw)) raw else matrix(raw, ncol = 1L)

  if (nrow(values) != nrow(locations) || ncol(values) != spec$sim_n) {
    stop(sprintf(
      "simulate_mc_scenario: unexpected simgc output shape %d x %d (expected %d x %d)",
      nrow(values), ncol(values), nrow(locations), spec$sim_n
    ))
  }

  log_info(
    "  draw summary: min=%g  median=%g  mean=%.3f  max=%g  zeros=%d/%d",
    min(values), stats::median(values), mean(values), max(values),
    sum(values == 0), length(values)
  )

  scenario <- make_scenario(
    config                  = spec,
    locations               = locations,
    values                  = values,
    true_params             = true_params,
    seed_info               = list(
      scheme = "direct",
      seed   = spec$seed,
      sim_n  = spec$sim_n
    ),
    coord_transform_applied = !is.null(coord_transform)
  )

  log_info("simulate_mc_scenario: done")
  scenario
}


#' Construct a fixed-configuration (non-Monte-Carlo) scenario.
build_fixed_scenario <- function(spec,
                                 locations,
                                 true_params = NULL) {

  stopifnot(
    is.list(spec),
    !is.null(spec$observed_values),
    is.matrix(locations), ncol(locations) == 2
  )

  values <- if (is.matrix(spec$observed_values)) {
    spec$observed_values
  } else {
    matrix(spec$observed_values, ncol = 1L)
  }

  log_info("build_fixed_scenario: dataset=%s  scenario=%s",
           spec$dataset_id, spec$scenario_id)
  log_info("  n_locations=%d  n_configurations=%d",
           nrow(locations), ncol(values))

  make_scenario(
    config      = spec,
    locations   = locations,
    values      = values,
    true_params = true_params,
    seed_info   = list(
      scheme = "fixed",
      seed   = NA_integer_,
      sim_n  = ncol(values)
    )
  )
}
