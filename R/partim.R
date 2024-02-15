#' @name partim
#' @title Partition Importance
#' @description \code{partim} calculates importance metrics for different types of regression models using a tree partitioning approach.
#'
#' @details Partition Importance is a procedure to obtain variable importance values for a regression model that sum to the \eqn{R^2} of the regression.
#'
#' The importance values approximate Shapley regression values (also known as 'LMG' (Lindeman _et al._, 1980) or dominance analysis), however are less computationally complex and only require calculation of \eqn{2k} instead of \eqn{2^k} regressions (where \eqn{k} is the number of features). This is achieved by computing explanations using a recursion along the branches of a hierarchical graph and calculation of coalition importance values at each split along the graph.
#'
#' Partition importance is model agnostic in the sense that any type of regression model (including regularized or nonlinear models) can be passed to \code{fEstimate} and \code{fExplain}. Here \code{fEstimate} is used to obtain initial fitted values of the model which are recursively explained, while \code{fEstimate} is the model that is used when calculating coalition Shapley values at each split. By default \code{fExplain} simply uses \code{fEstimate}, but the option exists to pass separate models here.
#'
#' At each split in the hierarchical graph coalition Shapley values are calculated using different weighting schemes given by \code{type}:
#'
#'  * \code{type = 'tree_lmg'} splits the common explanatory component equally between the two branches
#'  * \code{type = 'tree_pmvd'} splits the common component in proportion to the unique explanatory component (analogous to PMVD algorithm (Feldman, 2005))
#'  * \code{type = 'tree_entropy'} splits the common component based on the entropy of common variance loadings in each branch. This corrects the structural bias introduced by the hierarchical graph to some degree and typically performs better than the preceding methods at approximating LMG values.
#'
#' @param x the class of \code{object} determines which method is used. Can be either 'formula' or an object coercible to 'data.frame'. When it is a 'data.frame' it contains independent variables for the regression. Each row is an observation vector.
#' @param formula an object of class 'formula': a symbolic description of the model to be fitted.
#' @param data a 'data.frame' or an object coercible to 'data.frame' that contains all data referenced in \code{formula}.
#' @param y numerical response variable.
#' @param method method to use to partition importance among clusters. See Details.
#' @param add_intercept bool (default: TRUE). Should an intercept be added to \code{x}.
#' @param ... additional arguments passed to the fitting functions 'fEstimate' and 'fExplain'
#' @param fEstimate a function that takes arguments \code{x} and \code{y} and fits a regression model. This method is used to fit the initial regression of \code{y} on \code{x}, which is explained using fExplain. Must return an object with a 'fitted.values' attribute. Default: \code{stats::lm.fit}.
#' @param fExplain a function that takes arguments \code{x} and \code{y} and fits a regression model. The default behavior uses \code{fEstimate} for both model fitting and explaining, but different methods can be used by supplying an \code{fExplain} function. Must return an object with a 'fitted.values' attribute. Default: equal to \code{fEstimate}.
#' @param fCluster a function that takes an argument \code{x} and returns a vector of length \code{ncol(x)} which assigns the columns in \code{x} to exactly two clusters.
#' @return A named vector of importance values for each variable.
#'
#' @author Johann Pfitzinger
#'
#' @references
#'    Lindeman RH, Merenda PF, Gold RZ (1980). Introduction to Bivariate and Multivariate Analysis.
#'    Scott, Foresman, Glenview, IL.
#'
#'    Feldman, B. (2005) Relative Importance and Value SSRN Electronic Journal.
#'
#' @seealso \code{\link{fCluster}}, \code{\link{fEstimate}}
#'
#' @examples
#' data <- MASS::Boston
#' partim(medv ~ ., data, method = "tree_entropy")
#'
#' # Custom clustering function
#' partim(medv ~ ., data, fCluster = fCluster(type = "agnes", method = "ward"))
#'
#' # Explain a robust regression
#' partim(medv ~ ., data, fEstimate = MASS::rlm)
#'
#' @importFrom MASS rlm
#' @export partim
partim <- function(
    x,
    ...
    ) {
  UseMethod("partim")
}

#' @rdname partim
#' @export
partim.formula <- function(
    formula,
    data,
    method = c("tree_entropy", "tree_lmg", "tree_pmvd"),
    ...,
    fEstimate = stats::lm.fit,
    fExplain = NULL,
    fCluster = NULL
    ) {

  if (any(is.na(data)))
    stop("'NA' values in data are not allowed")

  mf <- stats::model.frame(formula, data)
  x <- stats::model.matrix(formula, mf)
  y <- stats::model.response(mf)

  if ("(Intercept)" %in% colnames(x)) {
    intercept <- TRUE
    x <- x[, colnames(x) != "(Intercept)"]
  }

  importance_values <- partim.default(x = x, y = y, method = method,
                                       fEstimate = fEstimate, fExplain = fExplain, fCluster = fCluster,
                                       ...)
  return(importance_values)
}

#' @rdname partim
#' @export
partim.default <- function(
    x,
    y,
    method = c("tree_entropy", "tree_lmg", "tree_pmvd"),
    add_intercept = TRUE,
    ...,
    fEstimate = stats::lm.fit,
    fExplain = NULL,
    fCluster = NULL
    ) {
  method <- match.arg(method)

  if (any(is.na(x)) || any(is.na(y)))
    stop("'NA' values in data are not allowed")

  if (is.null(fExplain))
    fExplain = fEstimate

  if (is.null(fCluster)) {
    fCluster <- fCluster()
  }

  nvar <- NCOL(x)

  # sanitize column names
  x <- as.data.frame(x)
  var_names <- colnames(x)
  syntactic_names <- make.names(var_names)
  var_names <- stats::setNames(var_names, syntactic_names)
  x <- data.frame(x, check.names = TRUE)
  x <- data.matrix(x)

  has_intercept <- any(apply(x, 2, stats::sd) == 0)
  if (add_intercept & !has_intercept) {
    x_fit <- cbind(1, x)
  } else {
    x_fit <- x
  }

  fitted_values <- .get_fitted_values(x, y, fEstimate, list(...))

  # initialize importance to R2
  rsq <- .get_rsq(y, fitted_values)
  importance <- stats::setNames(rep(rsq, nvar), names(var_names))

  # output environment
  output_env <- new.env()
  output_env$importance <- importance
  output_env$warnings <- NULL

  # tree recursion
  .partim_recursion(output_env, x, names(var_names), fitted_values, method, fExplain, fCluster, ...)

  importance_values <- output_env$importance
  names(importance_values) <- var_names[names(importance_values)]

  return(importance_values)
}
