# =====================================================================
# File:    code/configs/irregular.R
# Purpose: Configuration for the irregular sampling designs study.
#
# Study design:
#   - Same generating model as K13-A default: Poisson(5), range 0.3,
#     n = 49. What varies is the spatial layout:
#       * grid         : regular 7x7 (baseline; same as K13-A default)
#       * random       : 49 uniform random points in [0,1]^2
#       * clustered    : 49 points in 4 clusters, scatter 0.08
#   - 200 replicates per layout.
#
# All three scenarios share the same seed for the simulation, so any
# difference in estimation accuracy arises from the layout itself,
# not from sampling variability in the generating process.
# =====================================================================


irregular_spec <- function(scenario_id, layout_config, overrides = list()) {

  base <- list(
    dataset_id    = "IRREGULAR",
    scenario_id   = scenario_id,
    scenario_type = "monte_carlo",

    layout = layout_config,

    marginal = list(family = "poisson", link = "log", lambda = 5),
    corr     = list(family = "matern", range = 0.3, kappa = 0.5, nugget = 0),

    sim_n = 200L,
    seed  = 20240801L
  )

  merge_spec(base, overrides)
}


IRREGULAR_SCENARIOS <- list(

  grid = irregular_spec("grid", list(
    layout_type = "regular_grid",
    n_side      = 7L,
    xlim        = c(0, 1),
    ylim        = c(0, 1)
  )),

  random = irregular_spec("random", list(
    layout_type = "random_uniform",
    n           = 49L,
    xlim        = c(0, 1),
    ylim        = c(0, 1),
    seed        = 77701L                # layout-specific seed
  )),

  clustered = irregular_spec("clustered", list(
    layout_type = "clustered",
    n           = 49L,
    n_clusters  = 4L,
    scatter     = 0.08,
    xlim        = c(0, 1),
    ylim        = c(0, 1),
    seed        = 77702L
  ))
)
