#' @name fCluster
#' @title Returns a partialised clustering function that can be used to construct an importance tree in \code{partim}
#' @description \code{fCluster} is a wrapper for functions in the \code{cluster} package (\code{agnes}, \code{diana}, \code{pam}) and can be passed to \code{partim} to construct different types of hierarchical partitioning trees.
#'
#' @details \code{fCluster} creates a partialised function which only requires input data (\code{x}) and splits this data into 2 clusters using the preset clustering algorithm.
#'
#' Clustering is performed using a distance representation of \code{x}, such that distance matrix \eqn{d} is given by
#'
#' \eqn{d = ||1 - cor(x)^2||_2}
#'
#' The default approach partitions this distance matrix into 2 clusters at each recursive split along the tree using the Divisive Analysis algorithm (\code{cluster::diana}).
#'
#' @param type the function from the \code{cluster} package to use for clustering. Default: 'diana'.
#' @param ... additional arguments passed to the cluster function.
#' @param balanced boolean. When TRUE a balanced tree is constructed. When FALSE (the default) tree splits are determined using the clustering algorithm.
#' @return A vector of cluster assignments for each variable in \code{x}.
#'
#' @author Johann Pfitzinger
#'
#' @examples
#' data <- MASS::Boston
#'
#' # Calculate importance using balanced single-linkage tree
#' partim(medv ~ ., data, fCluster = fCluster("agnes", method = "single", balanced = TRUE))
#'
#' @seealso \code{\link{partim}}, \code{\link{fEstimate}}
#'
#' @references Maechler, M., Rousseeuw, P., Struyf, A., Hubert, M., Hornik, K.(2022).  cluster: Cluster Analysis Basics and Extensions. R package version 2.1.4.
#'
#' @importFrom purrr partial
#' @importFrom cluster agnes diana pam
#' @importFrom stats dist cor cutree setNames
#'
#' @export fCluster
fCluster <- function(
    type = c("diana", "agnes", "pam"),
    ...,
    balanced = FALSE
) {
  type <- match.arg(type)
  if (balanced & (type == "pam"))
    stop("'balanced' cannot be TRUE when 'type' is pam.")
  args <- list(...)
  cluster_function <- function(x, type, balanced, args) {
    if (NCOL(x) == 2) return(stats::setNames(c(1, 2), colnames(x)))
    distmat <- .get_distance_matrix(x)
    args[["x"]] <- distmat
    if (type == "diana") cl <- do.call(cluster::diana, args)
    if (type == "agnes") cl <- do.call(cluster::agnes, args)
    if (type == "pam") cl <- do.call(cluster::pam, append(list(k = 2), args))
    if (balanced) {
      clusters <- rep(2, NCOL(x))
      clusters[1:ceiling(NCOL(x)/2)] <- 1
      clusters <- clusters[cl$order]
    } else {
      if (type == "pam") {
        clusters <- cl$clustering
      } else {
        clusters <- stats::cutree(cl, k = 2)
      }
    }
    return(clusters)
  }
  return(purrr::partial(cluster_function, type = type, balanced = balanced, args = args))
}


.get_distance_matrix <- function(x) {
  distmat <- stats::dist(1 - abs(stats::cor(x))^2)
  return(distmat)
}
