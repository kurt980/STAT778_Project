# =====================================================================
# File:    code/R/grids.R
# Purpose: Generate spatial location matrices for simulation scenarios.
#
# CHANGES (from previous version):
#   - Added "random_uniform" branch: n locations drawn uniformly at
#     random in a rectangular domain.
#   - Added "clustered" branch: n locations drawn from a mixture of
#     Gaussian cluster centers with user-specified scatter.
#
# Everything else unchanged. The regular_grid branch still produces
# the same output as before, so existing datasets (H18-B, K13-A,
# K13A-GRID, MISSPEC, MISSING) are unaffected.
# =====================================================================


`%||%` <- function(a, b) if (is.null(a)) b else a


make_locations <- function(layout_type, ...) {
  args <- list(...)

  log_debug("make_locations: layout_type='%s'", layout_type)

  if (layout_type == "regular_grid")    return(.locations_regular_grid(args))
  if (layout_type == "random_uniform")  return(.locations_random_uniform(args))
  if (layout_type == "clustered")       return(.locations_clustered(args))

  stop(sprintf(
    "make_locations: unknown layout_type '%s'. Supported: 'regular_grid', 'random_uniform', 'clustered'.",
    layout_type
  ))
}


# ---- Existing regular grid layout ---------------------------------

.locations_regular_grid <- function(args) {
  n_side <- args$n_side %||% stop("regular_grid requires 'n_side'")
  xlim   <- args$xlim   %||% c(0, 1)
  ylim   <- args$ylim   %||% c(0, 1)

  stopifnot(
    is.numeric(n_side), length(n_side) == 1L, n_side >= 2L,
    is.numeric(xlim),   length(xlim)   == 2L, xlim[1] < xlim[2],
    is.numeric(ylim),   length(ylim)   == 2L, ylim[1] < ylim[2]
  )

  log_debug("  regular_grid: n_side=%d, xlim=[%g, %g], ylim=[%g, %g]",
            n_side, xlim[1], xlim[2], ylim[1], ylim[2])

  x_seq <- seq(xlim[1], xlim[2], length.out = n_side)
  y_seq <- seq(ylim[1], ylim[2], length.out = n_side)
  grid  <- expand.grid(x = x_seq, y = y_seq, KEEP.OUT.ATTRS = FALSE)
  locs  <- as.matrix(grid)

  log_debug("  produced %d locations", nrow(locs))
  locs
}


# ---- Random uniform layout ----------------------------------------

#' @section random_uniform args:
#' \describe{
#'   \item{n}{Integer. Number of locations.}
#'   \item{xlim, ylim}{Domain bounds, default c(0, 1).}
#'   \item{seed}{Integer, RNG seed for reproducibility. REQUIRED —
#'     otherwise the layout is non-deterministic.}
#' }
.locations_random_uniform <- function(args) {
  n    <- args$n    %||% stop("random_uniform requires 'n'")
  xlim <- args$xlim %||% c(0, 1)
  ylim <- args$ylim %||% c(0, 1)
  seed <- args$seed %||% stop("random_uniform requires 'seed' for reproducibility")

  stopifnot(
    is.numeric(n), length(n) == 1L, n >= 2L,
    is.numeric(xlim), length(xlim) == 2L, xlim[1] < xlim[2],
    is.numeric(ylim), length(ylim) == 2L, ylim[1] < ylim[2],
    is.numeric(seed), length(seed) == 1L
  )

  log_debug("  random_uniform: n=%d, seed=%d", n, seed)

  # Use a temporary RNG stream so we don't disturb any surrounding
  # seeding state (e.g. if simulate_mc_scenario seeds for simgc
  # immediately after).
  old_seed <- if (exists(".Random.seed", envir = globalenv())) {
    get(".Random.seed", envir = globalenv())
  } else NULL

  set.seed(seed)
  x <- runif(n, xlim[1], xlim[2])
  y <- runif(n, ylim[1], ylim[2])

  if (!is.null(old_seed)) {
    assign(".Random.seed", old_seed, envir = globalenv())
  }

  locs <- cbind(x = x, y = y)
  log_debug("  produced %d locations", nrow(locs))
  locs
}


# ---- Clustered layout ---------------------------------------------

#' Locations sampled from a mixture of Gaussian clusters.
#'
#' @section clustered args:
#' \describe{
#'   \item{n}{Integer. Total number of locations.}
#'   \item{n_clusters}{Integer. Number of cluster centers. Default 4.}
#'   \item{scatter}{Numeric. Standard deviation of Gaussian scatter
#'     around each center. Default 0.08.}
#'   \item{xlim, ylim}{Domain bounds, default c(0, 1). Centers and
#'     points are drawn inside these bounds (rejection sampling).}
#'   \item{seed}{Integer, RNG seed. REQUIRED.}
#' }
#'
#' Points that fall outside \code{xlim}/\code{ylim} are resampled. If
#' \code{scatter} is very large relative to \code{xlim}/\code{ylim},
#' this may take many iterations; the function stops after 10 * n
#' attempts and warns.
.locations_clustered <- function(args) {
  n          <- args$n          %||% stop("clustered requires 'n'")
  n_clusters <- args$n_clusters %||% 4L
  scatter    <- args$scatter    %||% 0.08
  xlim       <- args$xlim       %||% c(0, 1)
  ylim       <- args$ylim       %||% c(0, 1)
  seed       <- args$seed       %||% stop("clustered requires 'seed'")

  stopifnot(
    is.numeric(n), n >= n_clusters,
    is.numeric(n_clusters), n_clusters >= 2L,
    is.numeric(scatter), scatter > 0,
    is.numeric(seed)
  )

  log_debug("  clustered: n=%d, n_clusters=%d, scatter=%g, seed=%d",
            n, n_clusters, scatter, seed)

  old_seed <- if (exists(".Random.seed", envir = globalenv())) {
    get(".Random.seed", envir = globalenv())
  } else NULL

  set.seed(seed)

  # Draw cluster centers uniformly in the domain.
  centers <- cbind(
    runif(n_clusters, xlim[1] + 2 * scatter, xlim[2] - 2 * scatter),
    runif(n_clusters, ylim[1] + 2 * scatter, ylim[2] - 2 * scatter)
  )

  # Assign each point to a cluster (roughly balanced).
  cluster_ids <- rep_len(seq_len(n_clusters), n)

  # Draw points with Gaussian scatter around centers; reject if
  # outside the domain.
  locs <- matrix(NA_real_, nrow = n, ncol = 2)
  max_attempts <- 10 * n
  attempts <- 0
  i <- 1
  while (i <= n && attempts < max_attempts) {
    c_id <- cluster_ids[i]
    candidate <- centers[c_id, ] + rnorm(2, sd = scatter)
    if (candidate[1] >= xlim[1] && candidate[1] <= xlim[2] &&
        candidate[2] >= ylim[1] && candidate[2] <= ylim[2]) {
      locs[i, ] <- candidate
      i <- i + 1
    }
    attempts <- attempts + 1
  }

  if (!is.null(old_seed)) {
    assign(".Random.seed", old_seed, envir = globalenv())
  }

  if (i <= n) {
    warning(sprintf(
      "clustered layout: only %d/%d points accepted after %d attempts; scatter may be too large.",
      i - 1, n, max_attempts
    ))
    locs <- locs[seq_len(i - 1), , drop = FALSE]
  }

  colnames(locs) <- c("x", "y")
  log_debug("  produced %d locations (over %d attempts)", nrow(locs), attempts)
  locs
}
