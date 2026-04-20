# =====================================================================
# File:    code/R/logging.R
# Purpose: Lightweight, dependency-free logging helpers used throughout
#          the simulation pipeline.
#
# Design notes:
#   - All messages go to stdout via cat(), so they appear in both
#     interactive R sessions and in batch-mode log files when you run
#     `Rscript ... > log.txt 2>&1`.
#   - Debug messages are silenced by default; enable them via
#     options(sim_pipeline.debug = TRUE) before sourcing scripts.
#   - Timestamps include milliseconds so short-duration steps are
#     distinguishable in the log.
# =====================================================================


.log_timestamp <- function() {
  old_op <- options(digits.secs = 3)
  on.exit(options(old_op), add = TRUE)
  format(Sys.time(), "%Y-%m-%d %H:%M:%OS3")
}

.log_format <- function(fmt, ...) {
  extras <- list(...)
  if (length(extras) == 0L) fmt else do.call(sprintf, c(list(fmt), extras))
}


#' Log an informational message.
log_info <- function(fmt, ...) {
  cat(sprintf("[%s] [INFO ] %s\n", .log_timestamp(), .log_format(fmt, ...)))
  invisible(NULL)
}

#' Log a warning. Always emitted.
log_warn <- function(fmt, ...) {
  cat(sprintf("[%s] [WARN ] %s\n", .log_timestamp(), .log_format(fmt, ...)))
  invisible(NULL)
}

#' Log a debug message. Suppressed unless sim_pipeline.debug is TRUE.
log_debug <- function(fmt, ...) {
  if (!isTRUE(getOption("sim_pipeline.debug", FALSE))) {
    return(invisible(NULL))
  }
  cat(sprintf("[%s] [DEBUG] %s\n", .log_timestamp(), .log_format(fmt, ...)))
  invisible(NULL)
}

#' Log a horizontal rule for visual separation.
log_rule <- function(label = NULL) {
  bar <- strrep("=", 60)
  if (is.null(label)) {
    cat(bar, "\n", sep = "")
  } else {
    cat(sprintf("%s\n==  %s\n%s\n", bar, label, bar))
  }
  invisible(NULL)
}
