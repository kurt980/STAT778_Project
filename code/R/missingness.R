# =====================================================================
# File:    code/R/missingness.R
# Purpose: Post-generation missingness hooks.
#
# Provides:
#   apply_mcar()     - apply random (missing completely at random)
#                      masking to every replicate of a scenario.
#
# Design:
#   - Takes a scenario object (from simulate_mc_scenario), returns a
#     scenario object of the same schema. Integrates with the existing
#     pipeline: the fitter doesn't need to know missingness happened.
#   - The original values are preserved in $values_full; the masked
#     values go to $values. Both are NxB matrices; NA marks missing.
#   - Per-replicate independent masking (same scenario, different
#     replicates see different missing points).
#   - Seeding follows the same "hash of cell + replicate" convention:
#     seed is derived from the scenario's own seed plus a
#     missingness-specific salt.
# =====================================================================


#' Apply random (MCAR) missingness to a scenario.
#'
#' Given a scenario, randomly masks a fraction of each replicate's
#' observations as NA. The mask pattern is independent across
#' replicates but reproducible given the same input scenario and
#' missing_rate.
#'
#' @param scenario     A scenario object (as from simulate_mc_scenario).
#' @param missing_rate Fraction in (0, 1) of observations to drop
#'                     from each replicate.
#' @param seed_salt    Integer added to the scenario's seed to derive
#'                     a missingness-specific RNG stream. Default
#'                     99991 (a prime, so different salts don't alias
#'                     to the same stream).
#'
#' @return A modified scenario object:
#'   - $values: NxB matrix with some cells replaced by NA.
#'   - $values_full: the original pre-masking values.
#'   - $missingness_spec: a list recording how masking was done.
apply_mcar <- function(scenario, missing_rate, seed_salt = 99991L) {

  stopifnot(
    is.list(scenario),
    !is.null(scenario$values),
    is.numeric(missing_rate),
    length(missing_rate) == 1L,
    missing_rate > 0, missing_rate < 1
  )

  n <- nrow(scenario$values)
  B <- ncol(scenario$values)

  n_missing_per_rep <- round(n * missing_rate)
  stopifnot(n_missing_per_rep >= 1L, n_missing_per_rep < n)

  log_info("apply_mcar: rate=%.2f -> masking %d of %d per replicate",
           missing_rate, n_missing_per_rep, n)

  # Reproducible seeding. We use one set.seed call for the whole
  # function rather than one per replicate, so the masking pattern is
  # fully determined by (scenario$seed_info$seed, seed_salt,
  # missing_rate).
  set.seed(scenario$seed_info$seed + seed_salt +
           round(missing_rate * 1000))

  mask <- matrix(FALSE, nrow = n, ncol = B)
  for (b in seq_len(B)) {
    drop_idx <- sample.int(n, size = n_missing_per_rep, replace = FALSE)
    mask[drop_idx, b] <- TRUE
  }

  # Preserve the original before overwriting.
  out <- scenario
  out$values_full <- scenario$values

  masked <- scenario$values
  masked[mask] <- NA_real_
  out$values <- masked

  out$missingness_spec <- list(
    mechanism         = "MCAR",
    missing_rate      = missing_rate,
    n_missing_per_rep = n_missing_per_rep,
    seed_salt         = seed_salt
  )

  log_info("apply_mcar: total NA count = %d of %d cells",
           sum(is.na(out$values)), length(out$values))

  out
}
