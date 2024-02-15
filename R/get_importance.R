.get_importance <- function(x, y, groups, method, fEstimate, additional_args) {
  x_gra <- x[, groups[[1]]]
  x_grb <- x[, groups[[2]]]
  # calculate group models
  gr_a_fit <- .get_fitted_values(x_gra, y, fEstimate, additional_args)
  gr_b_fit <- .get_fitted_values(x_grb, y, fEstimate, additional_args)
  # calculate importance
  if (method == "tree_lmg") {
    importance <- .get_lmg_imp(y, gr_a_fit, gr_b_fit)
  }
  if (method == "tree_pmvd") {
    importance <- .get_pmvd_imp(y, gr_a_fit, gr_b_fit)
  }
  if (method == "tree_entropy") {
    importance <- .get_tree_weighted_imp(y, gr_a_fit, gr_b_fit, x_gra, x_grb)
  }
  names(importance$importance) <- names(groups)
  names(importance$fitted_values) <- names(groups)
  importance$importance <- (importance$importance + 1e-16) / sum(importance$importance + 1e-16)
  return(importance)
}
