# =====================================================================
# File:    code/R/plot_helpers.R
# Purpose: Utility functions for saving and displaying plots.
#
# Conventions:
#   - save_* functions take a plotting expression or object and write
#     to disk. They do not return the plot.
#   - All functions default to dir = "visualization/example".
# =====================================================================




#' Save a base-R plot to both PNG and PDF.
#'
#' Base R graphics cannot be captured after the fact; the plot
#' expression has to be replayed inside each graphics device. This
#' helper takes a quoted expression and evaluates it once per device,
#' so call sites can stay readable.
#'
#' @param expr    A quoted plotting expression (use quote() or bquote()).
#' @param filename Basename for the output, without extension. Both
#'                .png and .pdf are written.
#' @param dir     Output directory. Default "visualization/example".
#'                Created if missing.
#' @param width   Plot width in inches.
#' @param height  Plot height in inches.
#' @param res     PNG resolution (DPI). Ignored for PDF.
#'
#' @return Named character vector with the two written paths, invisibly.
#'
#' @examples
#' save_base_plot(quote(plot(1:10)), "demo")
save_base_plot <- function(expr,
                           filename,
                           dir    = "visualization/example",
                           width  = 7,
                           height = 6,
                           res    = 150) {
  
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  
  path_png <- file.path(dir, paste0(filename, ".png"))
  path_pdf <- file.path(dir, paste0(filename, ".pdf"))
  
  png(path_png, width = width * res, height = height * res, res = res)
  eval(expr)
  dev.off()
  
  pdf(path_pdf, width = width, height = height)
  eval(expr)
  dev.off()
  
  message("Saved: ", path_png, " and ", path_pdf)
  invisible(c(png = path_png, pdf = path_pdf))
}