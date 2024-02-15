
<!-- README.md is generated from README.Rmd. Please edit that file -->

# partim

<!-- badges: start -->

![CRAN](https://img.shields.io/cran/v/partim?label=CRAN)
<!-- badges: end -->

`partim` is an `R` package to compute relative importance for linear and
nonlinear regression models using a graph partitioning approach that
approximates Shapley regression values. The **relative importance** of
features in a regression measures the contribution of each feature to
the model prediction. When the goodness-of-fit of a model is measured
using $R^2$ (i.e. the percentage of target variance explained by the
model), then meaningful importance values should provide an additive
decomposition of $R^2$, such that the importance represents each
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

`partim` recursively splits that features (`x`) into two clusters and
allocates importance to each cluster using one of 3 available methods:

1.  `method = "tree_entropy"` (default) allocates to each cluster its
    unique variance contribution and divides any *common* variance
    contribution among the clusters (due to feature correlation) based
    on the entropy of common component loadings in the clusters. This
    adjusts for the structure of the hierarchical graph and closely
    approximates LMG values.
2.  `method = "tree_lmg"` allocates to each cluster its unique variance
    contribution and divides any *common* variance contribution equally
    among the clusters. This is exactly the LMG approach, but with a
    structural bias due to the hierarchical tree. It works best with
    balanced partition trees (see below).
3.  `method = "tree_pmvd"` allocates to each cluster its unique variance
    contribution and divides any *common* variance contribution in
    proportion to the unique contributions. This is the so-called
    “proportional marginal variance decomposition” (PMVD) approach.

[^1]: LMG is an acronym of the first letter of the authors’ surnames.
    `R` packages implementing the LMG method include `relaimpo` and
    `sensitivity`.
