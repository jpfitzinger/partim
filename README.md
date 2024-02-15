
<!-- README.md is generated from README.Rmd. Please edit that file -->

# partim

<!-- badges: start -->

![CRAN](https://img.shields.io/cran/v/partim?label=CRAN)
<!-- badges: end -->

`partim` is an `R` package to compute relative importance for linear and
nonlinear regression models using a graph partitioning approach that
approximates Shapley regression values. The **relative importance** of
features in a regression measures the **contribution of each feature to
the model prediction**. When the goodness-of-fit of a model is measured
using $R^2$ (i.e. the percentage of target variance explained by the
model), then meaningful importance values should provide an additive
decomposition of $R^2$, such that a feature’s importance represents that
feature’s percentage of target variance explained.

The most theoretically sound approach to decomposing explained variance
in a linear regression is the Shapley regression (typically referred to
as “LMG” in `R` packages implementing the technique[^1]). However, the
LMG method is computationally complex with an $\mathcal{O}(2^k)$ runtime
where $k$ is the number of features. Furthermore, LMG is limited to the
*linear* regression context with no implementation for regularized or
nonlinear models available in `R` (to the author’s knowledge).

This package makes two contributions:

1.  It provides a fast approximation of LMG that uses graph partitioning
    with an $\mathcal{O}(k^2)$ runtime
2.  It is generalizable to nonlinear and regularized regression models

## Installation

`partim` can be installed from
[Github](https://github.com/jpfitzinger/partim) with:

``` r
# Dev version
# install.packages("devtools")
devtools::install_github("jpfitzinger/partim")
library(partim)
```

## Overview and usage

The `partim` function computes importance values and can take `formula`
and `data` arguments or `x` and `y` arguments:

``` r
data <- MASS::Boston
imp <- partim(medv ~ ., data)

# ---- OR ----

x <- data[, 1:13]
y <- data[, 14]
imp <- partim(x, y)
```

`partim` recursively splits the features (`x`) into clusters and
allocates importance to each cluster using one of 3 available methods:

1.  `method = "tree_entropy"` (the default) allocates to each cluster
    its unique variance contribution and divides any *common* variance
    contribution based on the entropy of common component loadings in
    the clusters. This adjusts for the potentially unbalanced structure
    of the hierarchical graph and approximates LMG values.
2.  `method = "tree_lmg"` allocates to each cluster its unique variance
    contribution and divides any *common* variance contribution equally
    among the clusters. This is exactly the LMG approach, but with a
    structural bias due to the hierarchical tree. It works best with
    balanced partition trees (a discussion of different partition trees
    follows below).
3.  `method = "tree_pmvd"` allocates to each cluster its unique variance
    contribution and divides any *common* variance contribution in
    proportion to the unique contributions. This is the so-called
    “proportional marginal variance decomposition” (PMVD) approach
    (Feldman 2005).

## Custom clustering

How features are split into clusters can be controlled using the
`fCluster` argument. This argument takes a function that has a single
input `x` and returns a vector of cluster allocations. `partim` provides
an example wrapper method with the same name, which facilitates
pre-packaged correlation-based clustering with the `cluster` package
(Maechler et al. 2022):

``` r
# A balanced single-linkage tree
cl <- fCluster(type = "agnes", method = "single", balanced = TRUE)
imp_sl <- partim(medv ~ ., data, method = "tree_lmg", fCluster = cl)

# Correlation-based Divisive Analysis (the default)
cl <- fCluster(type = "diana")
imp_da <- partim(medv ~ ., data, fCluster = cl)

# Partitioning around medoids
cl <- fCluster(type = "pam")
imp_pam <- partim(medv ~ ., data, fCluster = cl)
```

As seen on the plot below, the choice of clustering algorithms can have
a marked impact on the importance values when data are correlated.
Generally, the divisive analysis (`diana`) algorithm has been observed
to yield the most robust results.

``` r
library(ggplot2)

plot_data <- dplyr::tibble(
  variable = colnames(x),
  `single linkage` = imp_sl,
  diana = imp_da,
  pam = imp_pam)

plot_data |> 
  tidyr::gather("method", "importance", -variable) |> 
  ggplot(aes(x = variable)) +
  geom_point(aes(y = importance, color = method)) +
  theme(legend.position = "top")
```

<img src="man/figures/README-unnamed-chunk-5-1.png" width="100%" />

## Custom model fitting

Partition importance explains **fitted variance** instead of the target
variable directly. Since 100% of the fitted variance is explained by the
model, the decomposition is recursively performed along a tree with the
relative importance values summing to one at each split. The product of
each branch’s importance yields feature-level importance values that can
be used to decompose the fitted model $R^2$ among the features.

Explaining fitted values also makes the approach model-agnostic.
Arbitrary model fitting methods can customized using the `fEstimate`
argument. The argument takes a function that has `x` and `y` inputs and
returns an object with a `fitted.values` attribute. Examples are
`stats::lm.fit`, `stats::lm.wfit` or `stats::rlm`. Once again, the
package provides a convenience wrapper for `lm`, `glmnet` and `nnet`
functions.

In the example below, an elastic net regression is fitted and explained
using the `tree_pmvd` method:

``` r
est <- fEstimate(type = "glmnet", alpha = 0.5, lambda = 1)
imp <- partim(medv ~ ., data, method = "tree_pmvd", fEstimate = est)

qplot(colnames(x), imp, xlab = "variable", ylab = "importance")
```

<img src="man/figures/README-unnamed-chunk-6-1.png" width="100%" />

It is important to note that when explaining a regularized regression
using the regularized method itself, the resulting importance values
will be regularized (and hence biased). In most cases, therefore, the
model used to allocate importance values at the splits should be more
flexible than the model used for fitting. `partim` accommodates this by
allowing a separate fitting function to be passed to `fExplain`:

``` r
imp <- partim(medv ~ ., data, method = "tree_pmvd", fEstimate = est, fExplain = lm.fit)
qplot(colnames(x), imp, xlab = "variable", ylab = "importance")
```

<img src="man/figures/README-unnamed-chunk-7-1.png" width="100%" />

## Nonlinear regression

`partim` can also be used in nonlinear regressions. This is interesting
since it provides a method for measuring (global) importance in black
box algorithms that accounts for feature dependence within an $R^2$
decomposition framework. To illustrate, I simulate a very simple
nonlinear problem:

``` r
set.seed(123)
# Four features, two of which represent noise
x <- matrix(rnorm(4*500), 500)
# Target variable with nonlinear DGP
y <- 
  x[,1] * ifelse(x[,1] > 0, -2, 2) + 
  x[,2] * ifelse(x[,2] > 0, -2, 2) + 
  rnorm(500)

# Linear importance
imp_lin <- partim(x, y)
# Nonlinear neural net importance
imp_nn <- partim(x, y, fEstimate = fEstimate("nnet", size=4, maxit=1000))

plot_data <- dplyr::tibble(
  variable = names(imp_lin),
  linear = imp_lin,
  nonlinear = imp_nn)

plot_data |> 
  tidyr::gather("method", "importance", -variable) |> 
  ggplot(aes(x = variable)) +
  geom_point(aes(y = importance, color = method)) +
  theme(legend.position = "top")
```

<img src="man/figures/README-unnamed-chunk-8-1.png" width="100%" />

The plot shows that (unsurprisingly) the linear regression is unable to
capture the nonlinear effect, while the neural network captures it
correctly, explaining a total of (just under) 80% of the variance in
`y`.

<div id="refs" class="references csl-bib-body hanging-indent">

<div id="ref-feldman_relative_2005" class="csl-entry">

Feldman, Barry. 2005. “Relative Importance and Value.”

</div>

<div id="ref-relaimpo" class="csl-entry">

Groemping, Ulrike. 2006. “Relative Importance for Linear Regression in
r: The Package Relaimpo.” *Journal of Statistical Software* 17 (1):
1–27.

</div>

<div id="ref-sensitivity" class="csl-entry">

Iooss, Bertrand, Sebastien Da Veiga, Alexandre Janon, Gilles Pujol, with
contributions from Baptiste Broto, Khalid Boumhaout, Laura Clouvel, et
al. 2024. *Sensitivity: Global Sensitivity Analysis of Model Outputs and
Importance Measures*. <https://CRAN.R-project.org/package=sensitivity>.

</div>

<div id="ref-lindeman_introduction_1980" class="csl-entry">

Lindeman, Richard Harold, Peter Francis Merenda, and Ruth Z. Gold. 1980.
*Introduction to Bivariate and Multivariate Analysis*. Glenview, Ill:
Scott, Foresman.

</div>

<div id="ref-cluster" class="csl-entry">

Maechler, Martin, Peter Rousseeuw, Anja Struyf, Mia Hubert, and Kurt
Hornik. 2022. *Cluster: Cluster Analysis Basics and Extensions*.
<https://CRAN.R-project.org/package=cluster>.

</div>

</div>

[^1]: LMG is an acronym of the first letter of the authors’ surnames,
    see Lindeman, Merenda, and Gold (1980). `R` packages implementing
    the LMG method include `relaimpo` (Groemping 2006) and `sensitivity`
    (Iooss et al. 2024).
