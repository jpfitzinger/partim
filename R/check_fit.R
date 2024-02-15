.check_fit <- function(fitted_object) {
  if (!is.null(fitted_object$error)) {
    stop(sprintf("calling 'fEstimate' failed with following error: %s", fitted_object$error))
  }
  if (length(fitted_object$result$warnings) > 0) {
    warning(sprintf("calling 'fEstimate' generated warning: %s", fitted_object$result$warning))
  }
}
