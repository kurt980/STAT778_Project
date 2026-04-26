# =====================================================================
# File:    code/R/fit_core.R
# Purpose: Core fitting utilities.
#
# CHANGE LOG (from previous version):
#   - .fit_one() now drops NA rows from y and the corresponding rows
#     of locs before calling mlegc. This makes fit_scenario() work
#     transparently with missingness-masked scenarios; no other
#     callers need to know.
#   - A new `n_used` field on each fit row records how many non-NA
#     observations were actually fit. This matters for analysis:
#     under 30% MCAR, n_used would be 0.7 * n instead of n.
#
# Everything else unchanged from the Day-3 version.
# =====================================================================


`%||%` <- function(a, b) if (is.null(a)) b else a


.build_marginal_for_fit <- function(marg_spec) {
  if (marg_spec$family == "poisson") return(poisson.gc())
  if (marg_spec$family == "negbin")  return(negbin.gc())
  if (marg_spec$family == "binomial") {
    size_val <- if (is.null(marg_spec$size)) 1 else marg_spec$size
    return(binomial.gc(size = size_val))
  }
  if (marg_spec$family == "zip") return(zip.gc())
  stop(sprintf(".build_marginal_for_fit: family '%s' not supported",
               marg_spec$family))
}


.build_corr_for_fit <- function(corr_spec) {
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
# Fit-result schema
# =====================================================================

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
# Fit one replicate
# =====================================================================

.fit_one <- function(scenario, replicate, method, fit_marg_spec) {

  y_full    <- scenario$values[, replicate]
  locs_full <- scenario$locations
  spec      <- scenario$config

  # NA-aware subsetting: drop rows where y is NA.
  # This is how missingness propagates through the pipeline transparently.
  observed_idx <- !is.na(y_full)
  y    <- y_full[observed_idx]
  locs <- locs_full[observed_idx, , drop = FALSE]

  n_used <- length(y)
  n_full <- length(y_full)

  marg <- .build_marginal_for_fit(fit_marg_spec)
  corr <- .build_corr_for_fit(spec$corr)

  # Default row: assume failure; overwrite on success.
  out <- data.frame(
    replicate     = replicate,
    method        = method,
    converged     = FALSE,
    error_message = NA_character_,
    runtime_sec   = NA_real_,
    n_used        = n_used,
    n_full        = n_full,
    loglik        = NA_real_,
    aic           = NA_real_,
    bic           = NA_real_,
    aicc          = NA_real_,
    stringsAsFactors = FALSE
  )
  out$estimates  <- list(NULL)
  out$std_errors <- list(NULL)

  # Defensive: if everything is NA, don't attempt to fit.
  if (n_used < 3) {
    out$error_message <- sprintf("n_used=%d too small to fit", n_used)
    return(out)
  }

  t0 <- Sys.time()

  fit <- tryCatch(
    mlegc(y = y, locs = locs, marginal = marg, corr = corr,
          method = method),
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

  out$converged <- TRUE
  out$loglik    <- tryCatch(fit$log.lik, error = function(e) NA_real_)
  out$aic       <- tryCatch(fit$AIC,     error = function(e) NA_real_)
  out$bic       <- tryCatch(fit$BIC,     error = function(e) NA_real_)
  out$aicc      <- tryCatch(fit$AICc,    error = function(e) NA_real_)

  # Use list(...) assignment to handle NULL safely (see Day-3 bug fix).
  est_val <- tryCatch(as.list(fit$MLE), error = function(e) NULL)
  out$estimates <- list(est_val)

  se_val <- tryCatch(
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
  out$std_errors <- list(se_val)

  out
}


# =====================================================================
# Misspecification detection
# =====================================================================

is_misspecified <- function(generating_spec, fitting_spec) {
  if (generating_spec$family != fitting_spec$family) return(TRUE)
  for (key in intersect(names(generating_spec), names(fitting_spec))) {
    if (key == "family") next
    if (!identical(generating_spec[[key]], fitting_spec[[key]])) return(TRUE)
  }
  FALSE
}


# =====================================================================
# Fit entire scenario
# =====================================================================

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

  generating_marg <- scenario$config$marginal
  fit_marg        <- fit_marginal_spec %||% generating_marg
  misspec         <- is_misspecified(generating_marg, fit_marg)

  # Detect whether the scenario has missingness applied. Purely for
  # log visibility; .fit_one handles NAs automatically regardless.
  has_missing <- any(is.na(scenario$values))

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
  log_info("  missingness:     %s",
           if (has_missing) sprintf("yes (%.1f%% masked)",
                                    100 * mean(is.na(scenario$values))) else "no")

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
      log_info("    -> %s  [%.2f sec, n_used=%d]",
               status, row$runtime_sec, row$n_used)
    }
  }

  results <- do.call(rbind, rows)

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
# Persistence
# =====================================================================

save_fit_result <- function(fit_result, dir = "data/fits") {

  stopifnot(is.list(fit_result),
            !is.null(fit_result$dataset_id),
            !is.null(fit_result$scenario_id))

  out_dir <- file.path(dir, fit_result$dataset_id)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

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


list_fit_results <- function(dataset_id, dir = "data/fits") {
  d <- file.path(dir, dataset_id)
  if (!dir.exists(d)) return(data.frame())

  files <- list.files(d, pattern = "\\.rds$", full.names = FALSE)
  stems <- tools::file_path_sans_ext(files)

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
