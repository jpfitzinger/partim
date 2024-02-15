.get_rsq <- function(y, fitted_values) {
  tss <- sum((y - mean(y))^2)
  rss <- sum((y - fitted_values)^2)
  return(1 - rss/tss)
}

.get_fitted_values <- function(x, y, fEstimate, additional_args) {
  if (NCOL(x) == 1) {
    x <- data.matrix(x)
  }
  fit_function <- purrr::safely(
    purrr::quietly(function(...) drop(fEstimate(...)$fitted.values)))
  x_fit <- cbind(1, x)
  fitted_object <- do.call(fit_function, append(list(x = x_fit, y = y), additional_args))
  .check_fit(fitted_object)
  fitted_values <- fitted_object$result$result
  return(fitted_values)
}

.get_lmg_imp <- function(y, gr_a, gr_b) {
  a <- .get_rsq(y, gr_a)
  b <- .get_rsq(y, gr_b)
  importance <- .weighted_average(a, b, 0.5)
  fitted_values <- .weighted_average(gr_a, gr_b, 0.5, y)
  return(list(importance = unlist(importance), fitted_values = fitted_values))
}

.get_pmvd_imp <- function(y, gr_a, gr_b) {
  a <- .get_rsq(y, gr_a)
  b <- .get_rsq(y, gr_b)
  r2.common <- a + b - 1
  r2.a.u <- a - r2.common
  r2.b.u <- b - r2.common
  w <- r2.a.u / c(r2.a.u + r2.b.u)
  importance <- .weighted_average(a, b, w)
  fitted_values <- .weighted_average(gr_a, gr_b, w, y)
  return(list(importance = unlist(importance), fitted_values = fitted_values))
}

.get_tree_weighted_imp <- function(y, gr_a, gr_b, x_gra, x_grb) {
  a <- .get_rsq(y, gr_a)
  b <- .get_rsq(y, gr_b)

  if ((stats::sd(gr_b) != 0) & (stats::sd(gr_a) != 0)){
    w.a <- drop(abs(cor(gr_b, x_gra))^2) + 1e-10
    w.a <- w.a / sum(w.a) * abs(cor(gr_b, gr_a))^2
    w.b <- drop(abs(cor(gr_a, x_grb))^2) + 1e-10
    w.b <- w.b / sum(w.b) * abs(cor(gr_b, gr_a))^2
  } else {
    w.a <- rep(1e-10, NCOL(x_gra))
    w.b <- rep(1e-10, NCOL(x_grb))
  }
  w.a <- exp(-sum(w.a * log(w.a)))
  w.b <- exp(-sum(w.b * log(w.b)))
  w <- sum(w.a) / sum(w.a, w.b)
  importance <- .weighted_average(a, b, w)
  fitted_values <- .weighted_average(gr_a, gr_b, w, y)
  return(list(importance = unlist(importance), fitted_values = fitted_values))
}

.weighted_average <- function(a, b, w, y = NULL) {
  if (is.null(y)) y <- 1
  av <- list()
  av[[1]] <- a * w + (y - b) * (1 - w)
  av[[2]] <- b * (1 - w) + (y - a) * w
  return(av)
}
