# =====================================================================
# File:    code/configs/zip.R
# Purpose: Configuration for the zero-inflation study.
#
# Study design:
#   - Three generating scenarios, each with a different zero-inflation
#     level p0 in {0, 0.2, 0.4}. p0=0 is pure Poisson (matches K13-A
#     default as sanity check); p0=0.2 and 0.4 are meaningfully
#     zero-inflated.
#   - The "mean" lambda under ZIP is 5 (matching K13-A default).
#     Zero-inflation adds point mass at zero; the non-zero component
#     is Poisson(lambda).
#   - Each generated scenario is fit two ways by the fitting script:
#     (a) as ZIP (well-specified when p0 > 0), (b) as Poisson
#     (misspecified when p0 > 0).
#
# Naming:
#   data/generated/ZIP/p0_0.rds    <- pure Poisson baseline
#   data/generated/ZIP/p0_20.rds
#   data/generated/ZIP/p0_40.rds
#
# Fit outputs include both well-specified and misspecified cases via
# the existing __misfit_<family> suffix convention.
# =====================================================================


zip_spec <- function(scenario_id, p0, overrides = list()) {

  base <- list(
    dataset_id    = "ZIP",
    scenario_id   = scenario_id,
    scenario_type = "monte_carlo",

    layout = list(layout_type = "regular_grid", n_side = 7L,
                  xlim = c(0, 1), ylim = c(0, 1)),

    # ZIP marginal: p0 is the zero-inflation probability, mu is
    # the mean parameter expected by gcKrig::zip.gc().
    marginal = list(family = "zip", link = "log",
                    mu = 5, od = p0),

    corr = list(family = "matern", range = 0.3, kappa = 0.5, nugget = 0),

    sim_n = 200L,
    seed  = as.integer(20240701L + round(p0 * 1000))
  )

  merge_spec(base, overrides)
}


ZIP_SCENARIOS <- list(
  p0_0  = zip_spec("p0_0",  0.0),
  p0_20 = zip_spec("p0_20", 0.2),
  p0_40 = zip_spec("p0_40", 0.4)
)
