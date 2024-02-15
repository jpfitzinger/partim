#' @name fEstimate
#' @title Returns a partialised estimation function that can be used for both estimation and explanation functions in \code{partim}
#' @description \code{fEstimate} is a wrapper for \code{stats::lm}, \code{glmnet::glmnet} and \code{nnet::nnet}, and can be passed to \code{partim} to be used for model estimation and/or explanations.
#'
#' @details \code{fEstimate} creates a partialised function which only requires input data (\code{x} and \code{y}) and returns an object with a 'fitted.values' attribute.
#'
#' When \code{type = 'lm'}, a linear regression model is fitted. Additional arguments such as weights can be passed to \code{...}
#' When \code{type = 'glmnet'} a regularized regression model (Elastic Net, Lasso, Ridge) can be fitted. Additional arguments such as 'lambda' or 'alpha' can be passed to \code{...}
#' When \code{type = 'nnet'} a simple neural network model is fitted. Additional arguments such as 'size' can be passed to \code{...}
#'
#' @param type the function to use for model fitting. Default: 'lm'.
#' @param ... additional arguments passed to the fitting function.
#' @return An object with a 'fitted.values' attribute.
#'
#' @author Johann Pfitzinger
#'
#' @examples
#' data <- MASS::Boston
#'
#' # Calculate importance of a Lasso regression
#' fEst <- fEstimate("glmnet", alpha = 1, lambda = 1)
#' partim(medv ~ ., data, fEstimate = fEst, fExplain = fEstimate("lm"))
#'
#' @seealso \code{\link{partim}}, \code{\link{fCluster}}
#'
#' @references
#'
#' Friedman J, Tibshirani R, Hastie T (2010). “Regularization Paths for Generalized Linear Models via Coordinate Descent.”
#' _Journal of Statistical Software_, *33*(1), 1-22. doi:10.18637/jss.v033.i01 <https://doi.org/10.18637/jss.v033.i01>.
#'
#' Venables, W. N. & Ripley, B. D. (2002) Modern Applied Statistics with S.
#' Fourth Edition. Springer, New York. ISBN 0-387-95457-0
#'
#' @importFrom stats lm predict
#'
#' @export fEstimate
fEstimate <- function(
    type = c("lm", "glmnet", "nnet"),
    ...
) {
  type = match.arg(type)
  if (type == "lm") required_package <- "stats"
  if (type == "glmnet") required_package <- "glmnet"
  if (type == "nnet") required_package <- "nnet"
  if (!required_package %in% utils::installed.packages())
    stop(sprintf("requires package '%s' to be installed. use install.packages('%s') to install it.", required_package, required_package))

  additional_args <- list(...)

  if (type == "lm") {
    fEstimate_inner <- function(x, y, additional_args) {
      mf <- data.frame(y = y, x)
      args <- append(list(formula = y~., data = mf), additional_args)
      mod <- do.call(stats::lm, args)
      return(mod)
    }
  }
  if (type == "glmnet") {
    if (is.null(additional_args$family)) additional_args$family <- "gaussian"
    if (is.null(additional_args$lambda)) {
      warning("must pass a 'lambda' argument. setting 'lambda = 0'")
      additional_args$lambda <- 0
    }
    if (additional_args$family != "gaussian")
      stop("this function currently only supports regressions ('family = 'gaussian')'.")
    fEstimate_inner <- function(x, y, additional_args) {
      if (NCOL(x) == 1) {
        x$TEMP_VAR_ <- 1
      }
      mod <- do.call(glmnet::glmnet, append(list(x = x, y = y), additional_args))
      fitted_values <- stats::predict(mod, data.matrix(x))
      return(list(fitted.values = fitted_values))
    }
  }
  if (type == "nnet") {
    if (is.null(additional_args$linout)) additional_args$linout <- TRUE
    if (additional_args$linout == FALSE)
      stop("this function currently only supports regressions ('linout = TRUE').")
    fEstimate_inner <- function(x, y, additional_args) {
      args <- append(list(x = x, y = y), additional_args)
      mod <- do.call(nnet::nnet, args)
      return(mod)
    }
  }

  return(purrr::partial(fEstimate_inner, additional_args = additional_args))
}
