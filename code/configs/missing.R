# =====================================================================
# File:    code/configs/missing.R
# Purpose: Configuration for the missingness extension study.
#
# Study design:
#   - Single generating scenario: Poisson(5) on 7x7, range 0.3, 200 reps.
#     (Same as K13-A default, keeps comparison clean with the baseline.)
#   - Missingness rates: {10%, 20%, 30%, 50%}.
#     Plus baseline (rate=0, no masking) to confirm the pipeline still
#     reproduces K13-A's numbers when nothing is masked.
#   - Mechanism: MCAR (missing completely at random), independent per
#     replicate.
#
# Output naming: the missingness rate is baked into the scenario_id
# via the builder, so each rate saves to its own file:
#   data/generated/MISSING/mcar_rate0.rds
#   data/generated/MISSING/mcar_rate10.rds
#   data/generated/MISSING/mcar_rate20.rds
#   data/generated/MISSING/mcar_rate30.rds
#   data/generated/MISSING/mcar_rate50.rds
#
# The fitter treats all five as ordinary scenarios; the NA-handling
# in .fit_one() does the right thing automatically.
# =====================================================================


#' Build a missingness-study scenario: same generating process as
#' K13-A default, but with an attached missingness rate.
#'
#' The scenario_id includes the rate, so each variant lands in its
#' own .rds file.
missing_spec <- function(scenario_id, missing_rate, overrides = list()) {

  base <- list(
    dataset_id    = "MISSING",
    scenario_id   = scenario_id,
    scenario_type = "monte_carlo",

    layout = list(layout_type = "regular_grid", n_side = 7L,
                  xlim = c(0, 1), ylim = c(0, 1)),

    marginal = list(family = "poisson", link = "log", lambda = 5),
    corr     = list(family = "matern", range = 0.3, kappa = 0.5, nugget = 0),

    sim_n = 200L,

    # All missing scenarios use the SAME seed so the underlying
    # simulated values are identical across rates; only the mask
    # differs. This makes the "same data, more missing" comparison
    # clean.
    seed = 20240601L,

    # Extra field: the missingness rate to apply. Read by the generation
    # script. Not used by simulate_mc_scenario (which just cares about
    # the model); handled as a post-generation step.
    missing_rate = missing_rate
  )

  merge_spec(base, overrides)
}


# Build the study: 5 rates from 0% to 50%.
MISSING_SCENARIOS <- list(
  mcar_rate0  = missing_spec("mcar_rate0",  0.00),
  mcar_rate10 = missing_spec("mcar_rate10", 0.10),
  mcar_rate20 = missing_spec("mcar_rate20", 0.20),
  mcar_rate30 = missing_spec("mcar_rate30", 0.30),
  mcar_rate50 = missing_spec("mcar_rate50", 0.50)
)
