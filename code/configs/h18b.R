# =====================================================================
# File:    code/configs/h18b.R
# Purpose: Configuration for Dataset H18-B.
#
# Source:  Han and De Oliveira (2018), Section 4.4.
#
# Exposes:
#   h18b_spec(scenario_id, overrides)  - builder for H18-B-family specs
#   H18B_SCENARIOS                     - named list of specs to generate
#
# The paper target is H18B_SCENARIOS$default. Do not edit it; add
# variants by appending to H18B_SCENARIOS (see bottom of file).
#
# Depends on:
#   merge_spec() from code/R/spec_utils.R. The generation script
#   sources that file before this one.
# =====================================================================


h18b_spec <- function(scenario_id = "default", overrides = list()) {

  base <- list(
    dataset_id    = "H18-B",
    scenario_id   = scenario_id,
    scenario_type = "monte_carlo",

    layout = list(
      layout_type = "regular_grid",
      n_side      = 11L,
      xlim        = c(0, 1),
      ylim        = c(0, 1)
    ),

    # beta = (intercept, x-coef, y-coef); mu(s) = exp(beta %*% (1, x, y)).
    marginal = list(
      family = "negbin",
      link   = "log",
      beta   = c(1.0, 0.5, 1.0),
      od     = 1
    ),

    corr = list(
      family = "matern",
      range  = 0.3,
      kappa  = 0.5,
      nugget = 0
    ),

    sim_n = 1L,
    seed  = 321L
  )

  merge_spec(base, overrides)
}


H18B_SCENARIOS <- list(
  default = h18b_spec()
)


# --- Example variants (commented out) --------------------------------

## Vary spatial dependence strength:
# for (r in c(0.1, 0.5, 0.7)) {
#   id <- sprintf("range_%g", r)
#   H18B_SCENARIOS[[id]] <- h18b_spec(id, list(corr = list(range = r)))
# }

## Vary overdispersion:
# for (od_val in c(0.5, 2, 3)) {
#   id <- sprintf("od_%g", od_val)
#   H18B_SCENARIOS[[id]] <- h18b_spec(id, list(marginal = list(od = od_val)))
# }

## Multiple replicates:
# H18B_SCENARIOS$mc_200 <- h18b_spec("mc_200", list(sim_n = 200L, seed = 2024L))

## Larger grid:
# H18B_SCENARIOS$grid_15 <- h18b_spec("grid_15", list(layout = list(n_side = 15L)))
