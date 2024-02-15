.partim_recursion <- function(output_env, x, x_names, y, method, fEstimate, fCluster, ...) {
  k <- NCOL(x)
  if ((k == 1) || (stats::sd(y) == 0)) {
    if (stats::sd(y) == 0) {
      output_env$importance[x_names] <- output_env$importance[x_names] / k
    }
    return(NULL)
  }
  clusters <- fCluster(x)
  if (length(clusters) != NCOL(x))
    stop("Invalid clustering. 'fCluster' should return a vector of length == NCOL(x)")
  if (length(unique(clusters)) != 2)
    stop("Invalid clustering. 'fCluster' must always return exactly two clusters")
  groups <- list()
  for (cl in unique(clusters)) {
    groups[[paste0("G", cl)]] <- colnames(x)[clusters == cl]
  }
  group_outputs <- .get_importance(x, y, groups, method, fEstimate, list(...))

  for (group in names(groups)) {
    grp_cols <- groups[[group]]
    imp <- group_outputs$importance[group]
    output_env$importance[grp_cols] <- output_env$importance[grp_cols] * imp
    x_grp <- x[, grp_cols]
    y_grp <- group_outputs$fitted_values[[group]]
    .partim_recursion(output_env, x_grp, grp_cols, y_grp, method, fEstimate, fCluster)
  }
}
