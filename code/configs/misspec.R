# =====================================================================
# File:    code/configs/misspec.R
# Purpose: Configuration for the Day-3 misspecification study.
#
# The study is a 2x2 matrix:
#
#                           | Fit as Poisson  | Fit as negbin
#     ---------------------|-----------------|------------------
#     Generate as Poisson   |  well-specified |  misspecified
#     Generate as negbin    |  misspecified   |  well-specified
#
# Two generating scenarios are needed:
#   (A) Poisson, already generated as K13-A/default.
#   (B) Negbin,  generated as MISSPEC/nbin_pilot by this config.
#
# Both use n=49, r=0.3, and 30 replicates (day-3 pilot).
#
# Why these parameter choices:
#   - Keep n and r identical so the comparison isolates the marginal.
#   - Poisson lambda=5 matches K13-A/default exactly.
#   - Negbin parameters chosen so the marginal mean and Poisson lambda
#     are the same (mean = exp(log(5)) = 5), with modest overdispersion
#     (od = 1). A Poisson fit to negbin data will see a mean that
#     matches but a variance that doesn't, which is exactly the regime
#     where misspecification bites.
#
# The actual fitting (which family to fit with) is controlled by the
# run script, not by this config. A single generating scenario can be
# fit both ways.
# =====================================================================


#' Builder for a K13-A-like Poisson scenario (generating family: Poisson).
#'
#' Same spec as K13A_SCENARIOS$default. Replicated here so that the
#' misspecification script can construct it without depending on the
#' K13-A config being sourced.
misspec_pois_spec <- function(scenario_id = "pois_pilot",
                              overrides   = list()) {
  base <- list(
    dataset_id    = "MISSPEC",
    scenario_id   = scenario_id,
    scenario_type = "monte_carlo",

    layout = list(layout_type = "regular_grid", n_side = 7L,
                  xlim = c(0, 1), ylim = c(0, 1)),

    marginal = list(family = "poisson", link = "log", lambda = 5),

    corr = list(family = "matern", range = 0.3, kappa = 0.5, nugget = 0),

    sim_n = 30L,
    seed  = 20240502L
  )

  merge_spec(base, overrides)
}


#' Builder for a negbin-generated version with the same marginal mean.
#'
#' mu(s) = exp(1 + 0*x + 0*y) = exp(1) ~ 2.72
#'
#' NOTE: we use the log-link negbin parameterization of gcKrig, with
#' beta = (intercept, x, y). Our H18B uses (1, 0.5, 1); here we set
#' (log(5), 0, 0) so the mean is 5 everywhere (constant, matching
#' the Poisson case). Overdispersion od = 1 gives variance mu + mu^2
#' = 5 + 25 = 30, vs Poisson variance of 5 -- so the data look
#' distinctly different from Poisson.
misspec_nbin_spec <- function(scenario_id = "nbin_pilot",
                              overrides   = list()) {
  base <- list(
    dataset_id    = "MISSPEC",
    scenario_id   = scenario_id,
    scenario_type = "monte_carlo",

    layout = list(layout_type = "regular_grid", n_side = 7L,
                  xlim = c(0, 1), ylim = c(0, 1)),

    marginal = list(family = "negbin", link = "log",
                    beta   = c(log(5), 0, 0),   # constant mean = 5
                    od     = 1),

    corr = list(family = "matern", range = 0.3, kappa = 0.5, nugget = 0),

    sim_n = 30L,
    seed  = 20240503L
  )

  merge_spec(base, overrides)
}


MISSPEC_SCENARIOS <- list(
  pois_pilot = misspec_pois_spec(),
  nbin_pilot = misspec_nbin_spec()
)
