# =====================================================================
# File:    code/configs/k13a_grid.R
# Purpose: Configuration for the Day-4 K13-A grid study.
#
# Source:  Kazianka (2013), Section 4, scoped down from the paper's
#          full 54-cell / 2000-replicate grid.
#
# Scope (reduced):
#   - Marginal:     Poisson only
#   - Sample size:  n in {25, 49}   (paper uses 25, 49, 81)
#   - Range:        r in {0.1, 0.3, 0.5}
#   - lambda:       gamma in {1, 5, 10}
#   - Replicates:   sim_n = 200     (paper uses 2000)
#
# Total: 2 * 3 * 3 = 18 cells x 200 reps x 2 methods = 7200 fits.
#
# Uses dataset_id = "K13A-GRID" to keep grid data separate from the
# Day-1 pilot's data/generated/K13-A/.
# =====================================================================


#' Build a spec for one cell of the K13-A grid.
k13a_grid_spec <- function(scenario_id, overrides = list()) {

  base <- list(
    dataset_id    = "K13A-GRID",
    scenario_id   = scenario_id,
    scenario_type = "monte_carlo",

    layout = list(layout_type = "regular_grid", n_side = 7L,
                  xlim = c(0, 1), ylim = c(0, 1)),

    marginal = list(family = "poisson", link = "log", lambda = 5),

    corr = list(family = "matern", range = 0.3, kappa = 0.5, nugget = 0),

    sim_n = 200L,
    seed  = 20240501L
  )

  merge_spec(base, overrides)
}


# Build all 18 cells programmatically
K13A_GRID_SCENARIOS <- list()

for (n_side in c(5L, 7L)) {
  n_total <- n_side * n_side

  for (rng in c(0.1, 0.3, 0.5)) {
    for (lam in c(1, 5, 10)) {

      id <- sprintf("pois_n%d_r%g_g%g", n_total, rng, lam)

      seed_val <- as.integer(n_total * 1e6 + round(rng * 1e4) + lam)

      K13A_GRID_SCENARIOS[[id]] <- k13a_grid_spec(id, list(
        layout   = list(n_side = n_side),
        corr     = list(range  = rng),
        marginal = list(lambda = lam),
        seed     = seed_val
      ))
    }
  }
}

stopifnot(length(K13A_GRID_SCENARIOS) == 18L)
