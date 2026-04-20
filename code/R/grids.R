# =====================================================================
# File:    code/R/grids.R
# Purpose: Generate spatial location matrices for simulation scenarios.
#
# Design notes:
#   - Single entry point make_locations() dispatches on layout_type.
#     Adding new layouts (clustered, sparse, transect, ...) means adding
#     a new branch; no existing caller needs to change.
#   - Row ordering matches expand.grid(x, y): x varies fastest.
#     This matches Han's convention in the gcKrig paper and matters
#     when reproducing a seeded simulation exactly.
#   - Output is always a 2-column numeric matrix with column names
#     c("x", "y"). simgc() accepts this directly.
# =====================================================================


`%||%` <- function(a, b) if (is.null(a)) b else a


#' Generate a set of spatial locations for a simulation scenario.
#'
#' @param layout_type "regular_grid" (more to come).
#' @param ... Layout-specific parameters. For "regular_grid":
#'   n_side (int, points per axis), xlim (default c(0,1)),
#'   ylim (default c(0,1)).
#' @return Numeric matrix with columns c("x","y").
make_locations <- function(layout_type, ...) {
  args <- list(...)

  log_debug("make_locations: layout_type='%s'", layout_type)

  if (layout_type == "regular_grid") {
    return(.locations_regular_grid(args))
  }

  stop(sprintf(
    "make_locations: unknown layout_type '%s'. Supported: 'regular_grid'.",
    layout_type
  ))
}


.locations_regular_grid <- function(args) {
  n_side <- args$n_side %||% stop("regular_grid requires 'n_side'")
  xlim   <- args$xlim   %||% c(0, 1)
  ylim   <- args$ylim   %||% c(0, 1)

  stopifnot(
    is.numeric(n_side), length(n_side) == 1L, n_side >= 2L,
    is.numeric(xlim),   length(xlim)   == 2L, xlim[1] < xlim[2],
    is.numeric(ylim),   length(ylim)   == 2L, ylim[1] < ylim[2]
  )

  log_debug(
    "  regular_grid: n_side=%d, xlim=[%g, %g], ylim=[%g, %g]",
    n_side, xlim[1], xlim[2], ylim[1], ylim[2]
  )

  x_seq <- seq(xlim[1], xlim[2], length.out = n_side)
  y_seq <- seq(ylim[1], ylim[2], length.out = n_side)
  grid  <- expand.grid(x = x_seq, y = y_seq, KEEP.OUT.ATTRS = FALSE)
  locs  <- as.matrix(grid)

  log_debug("  produced %d locations", nrow(locs))
  locs
}
