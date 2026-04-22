# =====================================================================
# File:    code/configs/k13a.R
# Purpose: Configuration for Dataset K13-A.
#
# Source:  Kazianka (2013), Stoch. Environ. Res. Risk Assess., Section 4.
#          "Approximate copula-based estimation and prediction of
#          discrete spatial data"
#
# Exposes:
#   k13a_spec(scenario_id, overrides)  - builder for K13-A-family specs
#   K13A_SCENARIOS                     - named list of specs to generate
#
# Convention: `default` is the paper-aligned baseline cell. Additional
# cells of the full 54-cell grid (Poisson/Bernoulli/geometric x 3
# params x 3 ranges x 3 sample sizes) will be added programmatically
# later, once the pilot confirms runtime and failure-rate expectations.
#
# Model for the `default` cell (Day-1 pilot):
#   Locations:   7 x 7 regular grid on [0,1]^2 (n = 49)
#   Marginal:    Poisson with mean (intensity) gamma = 5
#   Correlation: Exponential with range 0.3, no nugget.
#                (Matern with kappa = 0.5 equals exponential.)
#   Replicates:  sim_n = 30 (pilot; paper uses 2000)
#   Seed:        20240501 (arbitrary; changes only for distinct cells)
#
# Why these choices:
#   - Poisson gamma=5 is a middle-of-the-range parameter from Kazianka's
#     grid (which has 1, 5, 10). Not extreme in either direction.
#   - n = 49 is the middle sample size in the paper (25, 49, 81).
#   - range = 0.3 is "medium" spatial dependence in the paper's 0.1/0.3/0.5
#     grid.
#   - sim_n = 30 is enough to observe variability but finishes in
#     minutes for a day-1 pilot, even if GHK is slow.
#
# Depends on:
#   merge_spec() from code/R/spec_utils.R.
# =====================================================================


#' Build a K13-A-family scenario spec.
#'
#' @param scenario_id Identifier; used as filename at save time.
#' @param overrides   Partial overrides applied via merge_spec().
#'
#' @return A scenario spec list conforming to the project schema.
#'
#' @examples
#' # Pilot baseline (Day 1):
#' s0 <- k13a_spec()
#'
#' # Smaller n for fastest smoke test:
#' s1 <- k13a_spec("pilot_n25", list(
#'   layout = list(n_side = 5L)
#' ))
#'
#' # A weak-dependence variant:
#' s2 <- k13a_spec("range_0.1", list(
#'   corr = list(range = 0.1)
#' ))
k13a_spec <- function(scenario_id = "default", overrides = list()) {

  base <- list(
    dataset_id    = "K13-A",
    scenario_id   = scenario_id,
    scenario_type = "monte_carlo",

    layout = list(
      layout_type = "regular_grid",
      n_side      = 7L,                  # n = 49
      xlim        = c(0, 1),
      ylim        = c(0, 1)
    ),

    # Poisson marginal with a CONSTANT mean (no covariates in K13-A).
    # gcKrig's poisson.gc takes `lambda` as a scalar or vector;
    # we pass the scalar gamma = 5.
    marginal = list(
      family = "poisson",
      link   = "log",
      lambda = 5                         # Kazianka's gamma
    ),

    # Exponential correlation: Matern with kappa = 0.5.
    corr = list(
      family = "matern",
      range  = 0.3,
      kappa  = 0.5,
      nugget = 0
    ),

    sim_n = 200L,                         # pilot size; expand to 200 on Day 2
    seed  = 20240501L
  )

  merge_spec(base, overrides)
}


# =====================================================================
# Scenarios to generate
# =====================================================================

K13A_SCENARIOS <- list(
  default = k13a_spec()
)


# --- Future expansion (commented out until Day 2+) -------------------

## Full paper grid (Poisson only, restricted scope):
# for (n_side in c(5L, 7L, 9L)) {               # n = 25, 49, 81
#   for (rng in c(0.1, 0.3, 0.5)) {
#     for (lam in c(1, 5, 10)) {
#       id <- sprintf("pois_n%d_r%g_g%g", n_side^2, rng, lam)
#       K13A_SCENARIOS[[id]] <- k13a_spec(id, list(
#         layout   = list(n_side = n_side),
#         corr     = list(range  = rng),
#         marginal = list(lambda = lam),
#         # Stable but cell-specific seeds via a simple hash:
#         seed = as.integer(n_side * 1e6 + round(rng * 1e4) + lam)
#       ))
#     }
#   }
# }
