# =====================================================================
# File:    code/R/spec_utils.R
# Purpose: Utilities for constructing and manipulating scenario specs.
#
# Exposes:
#   merge_spec(base, overrides)
#
# Unlike base::modifyList(), merge_spec() descends into nested lists,
# so you can override a single leaf of a sublist without restating the
# rest of the sublist.
# =====================================================================


#' Recursively merge overrides into a base list.
#'
#' @examples
#' merge_spec(
#'   list(corr = list(family = "matern", range = 0.3, kappa = 0.5)),
#'   list(corr = list(range = 0.5))
#' )
#' # returns list(corr = list(family = "matern", range = 0.5, kappa = 0.5))
merge_spec <- function(base, overrides) {
  stopifnot(is.list(base), is.list(overrides))

  for (name in names(overrides)) {
    if (is.list(overrides[[name]]) && is.list(base[[name]])) {
      base[[name]] <- merge_spec(base[[name]], overrides[[name]])
    } else {
      base[[name]] <- overrides[[name]]
    }
  }

  base
}
