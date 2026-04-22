# =====================================================================
# File:    code/R/fit_core.R
# Purpose: Core fitting utilities.
#
#          make_fit_result()       - fit-result object factory (schema).
#          fit_scenario()          - fit every replicate in a scenario
#                                    with one or more methods; return a
#                                    fit-result object.
#                                    NEW: accepts a fit_marginal_spec
#                                    override for misspecification studies.
#
# Design notes:
#   - Parallel to sim_core.R: scenario objects describe inputs to
#     fitting; fit-result objects describe outputs of fitting.
#   - A fit-result object has one row per (replicate, method) pair.
#   - Errors in individual fits are caught per-replicate, so a bad fit
#     does NOT abort the scenario.
#   - All statistics are delegated to gcKrig::mlegc().
#   - MISSPECIFICATION: By default, fit_scenario uses the scenario's
#     generating-family for fitting (well-specified case). Pass
#     fit_marginal_spec to override this — e.g., generate negbin,
#     fit as poisson.
# =====================================================================


# =====================================================================
# Internal helpers
# =====================================================================

`%||%` <- function(a, b) if (is.null(a)) b else a


# Reconstruct gcKrig objects FOR FITTING.
#
# Distinct from the simulation-time helpers because:
#   - For simulation, marginal parameters are set at their TRUE values.
#   - For fitting, marginal parameters are NOT set — gcKrig estimates
#     them. We pass only the family/link, not the values.
#
# Note: gcKrig's poisson.gc() / negbin.gc() / binomial.gc() all have
# sensible defaults for `link`, so we avoid passing `link` explicitly
# (an earlier bug revealed that poisson.gc() is picky about how `link`
# is passed; the defaults are safe).

.build_marginal_for_fit <- function(marg_spec) {

  if (marg_spec$family == "poisson") {
    return(poisson.gc())
  }
  if (marg_spec$family == "negbin") {
    return(negbin.gc())
  }
  if (marg_spec$family == "binomial") {
    size_val <- if (is.null(marg_spec$size)) 1 else marg_spec$size
    return(binomial.gc(size = size_val))
  }
  if (marg_spec$family == "zip") {
    return(zip.gc())
  }

  stop(sprintf(".build_marginal_for_fit: family '%s' not supported",
               marg_spec$family))
}


.build_corr_for_fit <- function(corr_spec) {

  # `nugget = TRUE` tells gcKrig to estimate it; `FALSE` fixes at zero.
  # Our schema stores the generating nugget as a numeric (0 = "no
  # nugget in the generating model"). For fitting, we map 0 -> FALSE
  # (fix at 0) and any positive value -> TRUE (estimate it, though the
  # starting value is gcKrig's default).

  if (corr_spec$family == "matern") {
    return(matern.gc(kappa  = corr_spec$kappa,
                     nugget = corr_spec$nugget != 0))
  }
  if (corr_spec$family == "powerexp") {
    return(powerexp.gc(kappa  = corr_spec$kappa,
                       nugget = corr_spec$nugget != 0))
  }
  if (corr_spec$family == "spherical") {
    return(spherical.gc(nugget = corr_spec$nugget != 0))
  }

  stop(sprintf(".build_corr_for_fit: family '%s' not supported",
               corr_spec$family))
}


# =====================================================================
# Public: fit-result schema
# =====================================================================

#' Construct a fit-result object with the project's standard schema.
#'
#' @section Top-level fields:
#' \describe{
#'   \item{dataset_id, scenario_id}{Copied from the scenario.}
#'   \item{scenario_config}{Generating config, verbatim.}
#'   \item{fit_marginal_spec}{The marginal spec used for fitting.
#'     Equals scenario_config$marginal when fitting is well-specified
#'     (the default). Differs when misspecification is being studied.
#'     NEW in Day 3.}
#'   \item{misspecified}{Logical: TRUE iff fit_marginal_spec differs
#'     from scenario_config$marginal in family or family-specific
#'     params. Convenient flag for downstream analysis.}
#'   \item{results}{Data.frame, one row per (replicate, method).}
#'   \item{created_at, r_version, gcKrig_version}{Provenance.}
#' }
make_fit_result <- function(dataset_id,
                            scenario_id,
                            scenario_config,
                            fit_marginal_spec,
                            misspecified,
                            results) {

  stopifnot(
    is.character(dataset_id),   nzchar(dataset_id),
    is.character(scenario_id),  nzchar(scenario_id),
    is.list(scenario_config),
    is.list(fit_marginal_spec),
    is.logical(misspecified), length(misspecified) == 1L,
    is.data.frame(results)
  )

  list(
    dataset_id        = dataset_id,
    scenario_id       = scenario_id,
    scenario_config   = scenario_config,
    fit_marginal_spec = fit_marginal_spec,
    misspecified      = misspecified,
    results           = results,

    created_at     = Sys.time(),
    r_version      = R.version.string,
    gcKrig_version = tryCatch(
      as.character(packageVersion("gcKrig")),
      error = function(e) NA_character_
    )
  )
}


# =====================================================================
# Internal: fit one replicate with one method
# =====================================================================

# The marg_spec argument is the FITTING spec (may differ from the
# generating spec in scenario$config$marginal, for misspecification
# studies). Kept separate so .fit_one stays agnostic to whether the
# fit is well-specified.

.fit_one <- function(scenario, replicate, method, fit_marg_spec) {

  y    <- scenario$values[, replicate]
  locs <- scenario$locations
  spec <- scenario$config

  marg <- .build_marginal_for_fit(fit_marg_spec)
  corr <- .build_corr_for_fit(spec$corr)

  # Default row: assume failure; overwrite on success.
  out <- data.frame(
    replicate     = replicate,
    method        = method,
    converged     = FALSE,
    error_message = NA_character_,
    runtime_sec   = NA_real_,
    loglik        = NA_real_,
    aic           = NA_real_,
    bic           = NA_real_,
    aicc          = NA_real_,
    stringsAsFactors = FALSE
  )
  out$estimates  <- list(NULL)
  out$std_errors <- list(NULL)

  t0 <- Sys.time()

  fit <- tryCatch(
    mlegc(
      y        = y,
      locs     = locs,
      marginal = marg,
      corr     = corr,
      method   = method
    ),
    error = function(e) {
      structure(list(error_message = conditionMessage(e)),
                class = "fit_error")
    }
  )

  out$runtime_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  if (inherits(fit, "fit_error")) {
    out$error_message <- fit$error_message
    return(out)
  }

  # --- Extract statistics (defensively; field names are stable in
  # current gcKrig but tryCatch guards against version drift) --------

  out$converged <- TRUE
  out$loglik    <- tryCatch(fit$log.lik, error = function(e) NA_real_)
  out$aic       <- tryCatch(fit$AIC,     error = function(e) NA_real_)
  out$bic       <- tryCatch(fit$BIC,     error = function(e) NA_real_)
  out$aicc      <- tryCatch(fit$AICc,    error = function(e) NA_real_)

  out$estimates[[1]] <- tryCatch(as.list(fit$MLE), error = function(e) NULL)

  # Compute SEs from the Hessian. gcKrig doesn't store SEs directly in
  # the returned object; the Hessian is there and SE = sqrt(diag(H^-1)).
  out$std_errors[[1]] <- tryCatch(
    {
      if (!is.null(fit$hessian)) {
        se_vec <- sqrt(diag(solve(fit$hessian)))
        if (!is.null(names(fit$MLE))) names(se_vec) <- names(fit$MLE)
        as.list(se_vec)
      } else {
        NULL
      }
    },
    error = function(e) NULL
  )

  out
}


# =====================================================================
# Public: misspecification detection
# =====================================================================

#' Test whether a fit_marginal_spec differs from a generating marginal.
#'
#' Returns TRUE iff the two specs differ in `family` OR in any
#' family-specific numeric parameter that was set on both.
#'
#' @examples
#' # Same family + same param -> well-specified
#' is_misspecified(list(family = "poisson", lambda = 5),
#'                 list(family = "poisson", lambda = 5))  # FALSE
#'
#' # Different family -> misspecified
#' is_misspecified(list(family = "poisson", lambda = 5),
#'                 list(family = "negbin", beta = c(1,0,0), od = 1))  # TRUE
is_misspecified <- function(generating_spec, fitting_spec) {
  if (generating_spec$family != fitting_spec$family) return(TRUE)

  # Same family: check family-specific params that are set on both.
  for (key in intersect(names(generating_spec), names(fitting_spec))) {
    if (key == "family") next
    if (!identical(generating_spec[[key]], fitting_spec[[key]])) return(TRUE)
  }
  FALSE
}


# =====================================================================
# Public: fit every replicate with every method
# =====================================================================

#' Fit all replicates of a scenario with a set of methods.
#'
#' @param scenario          A scenario object.
#' @param methods           Character vector. Default c("GHK", "GQT").
#' @param replicates        Integer vector. Default = all.
#' @param fit_marginal_spec Optional list. If NULL (default), fit uses
#'   the scenario's generating marginal (well-specified). If provided,
#'   fit uses this spec instead (misspecification study).
#'
#'   Example for misspecification:
#'
#'     fit_marginal_spec = list(family = "poisson")
#'
#'   will fit every replicate as Poisson, regardless of what the data
#'   was generated from.
#'
#' @return A fit-result object; see make_fit_result().
fit_scenario <- function(scenario,
                         methods           = c("GHK", "GQT"),
                         replicates        = NULL,
                         fit_marginal_spec = NULL) {

  stopifnot(is.list(scenario), !is.null(scenario$values))

  sim_n <- ncol(scenario$values)
  if (is.null(replicates)) replicates <- seq_len(sim_n)

  stopifnot(
    all(replicates >= 1), all(replicates <= sim_n),
    all(methods %in% c("GHK", "GQT"))
  )

  # Resolve the fitting marginal spec.
  generating_marg <- scenario$config$marginal
  fit_marg        <- fit_marginal_spec %||% generating_marg
  misspec         <- is_misspecified(generating_marg, fit_marg)

  log_info("fit_scenario: dataset=%s  scenario=%s",
           scenario$dataset_id, scenario$scenario_id)
  log_info("  methods:         %s", paste(methods, collapse = ", "))
  log_info("  replicates:      %d of %d (%s)",
           length(replicates), sim_n,
           if (length(replicates) == sim_n) "all" else "subset")
  log_info("  total fits:      %d", length(replicates) * length(methods))
  log_info("  generating fam:  %s", generating_marg$family)
  log_info("  fitting fam:     %s", fit_marg$family)
  log_info("  misspecified:    %s", misspec)

  rows <- list()
  idx  <- 0L

  for (rep_i in replicates) {
    for (m in methods) {
      idx <- idx + 1L
      log_info("  fit %d/%d: replicate=%d method=%s ...",
               idx, length(replicates) * length(methods), rep_i, m)

      row <- .fit_one(scenario, rep_i, m, fit_marg)
      rows[[idx]] <- row

      status <- if (row$converged) "ok" else sprintf("FAIL (%s)", row$error_message)
      log_info("    -> %s  [%.2f sec]", status, row$runtime_sec)
    }
  }

  results <- do.call(rbind, rows)

  # --- Summary log --------------------------------------------------
  n_ok   <- sum(results$converged)
  n_fail <- sum(!results$converged)
  log_info("fit_scenario: done  (ok=%d, fail=%d)", n_ok, n_fail)

  if (n_ok > 0) {
    for (m in methods) {
      sub <- results[results$method == m & results$converged, ]
      if (nrow(sub) > 0) {
        log_info("  %s: mean runtime = %.3f sec  (n=%d)",
                 m, mean(sub$runtime_sec), nrow(sub))
      }
    }
  }

  make_fit_result(
    dataset_id        = scenario$dataset_id,
    scenario_id       = scenario$scenario_id,
    scenario_config   = scenario$config,
    fit_marginal_spec = fit_marg,
    misspecified      = misspec,
    results           = results
  )
}


# =====================================================================
# Public: save / load fit results
# =====================================================================

save_fit_result <- function(fit_result, dir = "data/fits") {

  stopifnot(is.list(fit_result),
            !is.null(fit_result$dataset_id),
            !is.null(fit_result$scenario_id))

  out_dir <- file.path(dir, fit_result$dataset_id)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  # For misspecified fits, append a suffix so the output doesn't
  # overwrite the well-specified fit of the same scenario. Convention:
  #   well-specified:  data/fits/K13-A/default.rds
  #   misspecified:    data/fits/K13-A/default__misfit_poisson.rds
  suffix <- if (fit_result$misspecified) {
    sprintf("__misfit_%s", fit_result$fit_marginal_spec$family)
  } else {
    ""
  }

  out_path <- file.path(out_dir, paste0(fit_result$scenario_id, suffix, ".rds"))

  if (file.exists(out_path)) {
    log_warn("save_fit_result: overwriting %s", out_path)
  }

  saveRDS(fit_result, out_path)
  log_info("save_fit_result: wrote %s (%.1f KB)",
           out_path, file.info(out_path)$size / 1024)

  invisible(out_path)
}


load_fit_result <- function(dataset_id,
                            scenario_id,
                            misspec_family = NULL,
                            dir = "data/fits") {

  suffix <- if (!is.null(misspec_family)) {
    sprintf("__misfit_%s", misspec_family)
  } else {
    ""
  }

  path <- file.path(dir, dataset_id, paste0(scenario_id, suffix, ".rds"))
  if (!file.exists(path)) stop(sprintf("load_fit_result: not found: %s", path))
  readRDS(path)
}


#' List fit-result files available for a dataset.
#'
#' Returns a data.frame with columns scenario_id and misspec_family
#' (NA for well-specified fits).
list_fit_results <- function(dataset_id, dir = "data/fits") {
  d <- file.path(dir, dataset_id)
  if (!dir.exists(d)) return(data.frame())

  files <- list.files(d, pattern = "\\.rds$", full.names = FALSE)
  stems <- tools::file_path_sans_ext(files)

  # Parse "<scen_id>" or "<scen_id>__misfit_<family>"
  m <- regmatches(stems, regexec("^(.+?)(?:__misfit_(.+))?$", stems))
  parsed <- do.call(rbind, lapply(m, function(x) {
    scen_id <- x[2]
    mf      <- if (length(x) >= 3 && nzchar(x[3])) x[3] else NA_character_
    data.frame(scenario_id    = scen_id,
               misspec_family = mf,
               stringsAsFactors = FALSE)
  }))

  parsed
}
