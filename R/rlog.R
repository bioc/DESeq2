#' Apply a 'regularized log' transformation
#'
#' This function transforms the count data to the log2 scale in a way 
#' which minimizes differences between samples for rows with small counts,
#' and which normalizes with respect to library size.
#' The rlog transformation produces a similar variance stabilizing effect as
#' \code{\link{varianceStabilizingTransformation}},
#' though \code{rlog} is more robust in the
#' case when the size factors vary widely.
#' The transformation is useful when checking for outliers
#' or as input for machine learning techniques
#' such as clustering or linear discriminant analysis.
#' \code{rlog} takes as input a \code{\link{DESeqDataSet}} and returns a
#' \code{\link{RangedSummarizedExperiment}} object.
#'
#' Note that neither rlog transformation nor the VST are used by the
#' differential expression estimation in \code{\link{DESeq}}, which always
#' occurs on the raw count data, through generalized linear modeling which
#' incorporates knowledge of the variance-mean dependence. The rlog transformation
#' and VST are offered as separate functionality which can be used for visualization,
#' clustering or other machine learning tasks. See the transformation section of the
#' vignette for more details, including a statement on timing. If \code{rlog}
#' is run on data with number of samples in [30-49] it will print a message
#' that it may take a few minutes, if the number of samples is 50 or larger, it
#' will print a message that it may take a "long time", and in both cases, it
#' will mention that the \code{\link{vst}} is a much faster transformation.
#'
#' The transformation does not require that one has already estimated size factors
#' and dispersions.
#'
#' The regularization is on the log fold changes of the count for each sample
#' over an intercept, for each gene. As nearby count values for low counts genes
#' are almost as likely as the observed count, the rlog shrinkage is greater for low counts.
#' For high counts, the rlog shrinkage has a much weaker effect.
#' The fitted dispersions are used rather than the MAP dispersions
#' (so similar to the \code{\link{varianceStabilizingTransformation}}).
#' 
#' The prior variance for the shrinkag of log fold changes is calculated as follows: 
#' a matrix is constructed of the logarithm of the counts plus a pseudocount of 0.5,
#' the log of the row means is then subtracted, leaving an estimate of
#' the log fold changes per sample over the fitted value using only an intercept.
#' The prior variance is then calculated by matching the upper quantiles of the observed 
#' log fold change estimates with an upper quantile of the normal distribution.
#' A GLM fit is then calculated using this prior. It is also possible to supply the variance of the prior.
#' See the vignette for an example of the use and a comparison with \code{varianceStabilizingTransformation}.
#'
#' The transformed values, rlog(K), are equal to
#' \eqn{rlog(K_{ij}) = \log_2(q_{ij}) = \beta_{i0} + \beta_{ij}}{rlog(K_ij) = log2(q_ij) = beta_i0 + beta_ij},
#' with formula terms defined in \code{\link{DESeq}}.
#'
#' The parameters of the rlog transformation from a previous dataset
#' can be frozen and reapplied to new samples. See the 'Data quality assessment'
#' section of the vignette for strategies to see if new samples are
#' sufficiently similar to previous datasets. 
#' The frozen rlog is accomplished by saving the dispersion function,
#' beta prior variance and the intercept from a previous dataset,
#' and running \code{rlog} with 'blind' set to FALSE
#' (see example below).
#' 
#' @aliases rlog rlogTransformation
#' @rdname rlog
#' @name rlog
#' 
#' @param object a DESeqDataSet, or matrix of counts
#' @param blind logical, whether to blind the transformation to the experimental
#' design. blind=TRUE should be used for comparing samples in an manner unbiased by
#' prior information on samples, for example to perform sample QA (quality assurance).
#' blind=FALSE should be used for transforming data for downstream analysis,
#' where the full use of the design information should be made.
#' blind=FALSE will skip re-estimation of the dispersion trend, if this has already been calculated.
#' If many of genes have large differences in counts due to
#' the experimental design, it is important to set blind=FALSE for downstream
#' analysis.
#' @param intercept by default, this is not provided and calculated automatically.
#' if provided, this should be a vector as long as the number of rows of object,
#' which is log2 of the mean normalized counts from a previous dataset.
#' this will enforce the intercept for the GLM, allowing for a "frozen" rlog
#' transformation based on a previous dataset.
#' You will also need to provide \code{mcols(object)$dispFit}.
#' @param betaPriorVar a single value, the variance of the prior on the sample
#' betas, which if missing is estimated from the data
#' @param fitType in case dispersions have not yet been estimated for \code{object},
#' this parameter is passed on to \code{\link{estimateDispersions}} (options described there).
#' 
#' @return a \code{\link{DESeqTransform}} if a \code{DESeqDataSet} was provided,
#' or a matrix if a count matrix was provided as input.
#' Note that for \code{\link{DESeqTransform}} output, the matrix of
#' transformed values is stored in \code{assay(rld)}.
#' To avoid returning matrices with NA values, in the case of a row
#' of all zeros, the rlog transformation returns zeros
#' (essentially adding a pseudocount of 1 only to these rows).
#'
#' @references
#'
#' Reference for regularized logarithm (rlog):
#' 
#' Michael I Love, Wolfgang Huber, Simon Anders: Moderated estimation of fold change and dispersion for RNA-seq data with DESeq2. Genome Biology 2014, 15:550. \url{http://dx.doi.org/10.1186/s13059-014-0550-8}
#' 
#' @seealso \code{\link{plotPCA}}, \code{\link{varianceStabilizingTransformation}}, \code{\link{normTransform}}
#' @examples
#'
#' dds <- makeExampleDESeqDataSet(m=6,betaSD=1)
#' rld <- rlog(dds)
#' dists <- dist(t(assay(rld)))
#' # plot(hclust(dists))
#'
#' @export
rlog <- function(object, blind=TRUE, intercept, betaPriorVar, fitType="parametric") {
  n <- ncol(object)
  if (n >= 30 & n < 50) {
    message("rlog() may take a few minutes with 30 or more samples,
vst() is a much faster transformation")
  } else if (n >= 50) {
    message("rlog() may take a long time with 50 or more samples,
vst() is a much faster transformation")
  }
  if (is.null(colnames(object))) {
    colnames(object) <- seq_len(ncol(object))
  }
  if (is.matrix(object)) {
    matrixIn <- TRUE
    object <- DESeqDataSetFromMatrix(object, DataFrame(row.names=colnames(object)), ~ 1)
  } else {
    matrixIn <- FALSE
  }
  if (is.null(sizeFactors(object)) & is.null(normalizationFactors(object))) {
    object <- estimateSizeFactors(object)
  }
  if (blind) {
    design(object) <- ~ 1
  }
  # sparsity test
  if (missing(intercept)) {
    sparseTest(counts(object, normalized=TRUE), .9, 100, .1)
  }
  if (blind | is.null(mcols(object)$dispFit)) {
    # estimate the dispersions on all genes
    if (is.null(mcols(object)$baseMean)) {
      object <- getBaseMeansAndVariances(object)
    }
    object <- estimateDispersionsGeneEst(object, quiet=TRUE)
    object <- estimateDispersionsFit(object, fitType, quiet=TRUE)
  }
  if (!missing(intercept)) {
    if (length(intercept) != nrow(object)) {
      stop("intercept should be as long as the number of rows of object")
    }
  }
  rld <- rlogData(object, intercept, betaPriorVar)
  if (matrixIn) {
    return(rld)
  }
  se <- SummarizedExperiment(
           assays = rld,
           colData = colData(object),
           rowRanges = rowRanges(object),
           metadata = metadata(object))
  dt <- DESeqTransform(se)
  attr(dt,"betaPriorVar") <- attr(rld, "betaPriorVar")
  if (!is.null(attr(rld,"intercept"))) {
    mcols(dt)$rlogIntercept <- attr(rld,"intercept")
  }
  dt
}

#' @rdname rlog
#' @export
rlogTransformation <- rlog

###################### unexported

rlogData <- function(object, intercept, betaPriorVar) {
  if (is.null(mcols(object)$dispFit)) {
    stop("first estimate dispersion")
  }
  samplesVector <- as.character(seq_len(ncol(object)))
  if (!missing(intercept)) {
    if (length(intercept) != nrow(object)) {
      stop("intercept should be as long as the number of rows of object")
    }
  }
  if (is.null(mcols(object)$allZero) | is.null(mcols(object)$baseMean)) {
    object <- getBaseMeansAndVariances(object)
  }
  
  # make a design matrix with a term for every sample
  # this would typically produce unidentifiable solution
  # for the GLM, but we add priors for all terms except
  # the intercept
  samplesVector <- factor(samplesVector,levels=unique(samplesVector))
  if (missing(intercept)) {
    samples <- factor(c("null_level",as.character(samplesVector)),
                      levels=c("null_level",levels(samplesVector)))
    modelMatrix <- stats::model.matrix.default(~samples)[-1,]
    modelMatrixNames <- colnames(modelMatrix)
    modelMatrixNames[modelMatrixNames == "(Intercept)"] <- "Intercept"
  } else {
    # or we want to set the intercept using the
    # provided intercept instead
    samples <- factor(samplesVector)
    if (length(samples) > 1) {
      modelMatrix <- stats::model.matrix.default(~ 0 + samples)
    } else {
      modelMatrix <- matrix(1,ncol=1)
      modelMatrixNames <- "samples1"
    }
    modelMatrixNames <- colnames(modelMatrix)
    if (!is.null(normalizationFactors(object))) { 
      nf <- normalizationFactors(object)
    } else {
      sf <- sizeFactors(object)
      nf <- matrix(rep(sf,each=nrow(object)),ncol=ncol(object))
    }
    # if the intercept is not finite, these rows
    # were all zero. here we put a small value instead
    intercept <- as.numeric(intercept)
    infiniteIntercept <- !is.finite(intercept)
    intercept[infiniteIntercept] <- -10
    normalizationFactors(object) <- nf * 2^intercept
    # we set the intercept, so replace the all zero
    # column with the rows which were all zero
    # in the previous dataset
    mcols(object)$allZero <- infiniteIntercept
  }

  # only continue on the rows with non-zero row sums
  objectNZ <- object[!mcols(object)$allZero,]
  stopifnot(all(!is.na(mcols(objectNZ)$dispFit)))
  
  # if a prior sigma squared not provided, estimate this
  # by the matching upper quantiles of the
  # log2 counts plus a pseudocount
  if (missing(betaPriorVar)) {
    logCounts <- log2(counts(objectNZ,normalized=TRUE) + 0.5)
    logFoldChangeMatrix <- logCounts - log2(mcols(objectNZ)$baseMean + 0.5)
    logFoldChangeVector <- as.numeric(logFoldChangeMatrix)
    varlogk <- 1/mcols(objectNZ)$baseMean + mcols(objectNZ)$dispFit
    weights <- 1/varlogk   
    betaPriorVar <- matchWeightedUpperQuantileForVariance(logFoldChangeVector, rep(weights,ncol(objectNZ)))
  }
  stopifnot(length(betaPriorVar)==1)
  
  lambda <- 1/rep(betaPriorVar,ncol(modelMatrix))
  # except for intercept which we set to wide prior
  if ("Intercept" %in% modelMatrixNames) {
    lambda[which(modelMatrixNames == "Intercept")] <- 1e-6
  }
  
  fit <- fitNbinomGLMs(object=objectNZ, modelMatrix=modelMatrix,
                       lambda=lambda, renameCols=FALSE,
                       alpha_hat=mcols(objectNZ)$dispFit,
                       betaTol=1e-4, useOptim=FALSE,
                       useQR=TRUE)
  normalizedDataNZ <- t(modelMatrix %*% t(fit$betaMatrix))

  normalizedData <- buildMatrixWithZeroRows(normalizedDataNZ, mcols(object)$allZero)

  # add back in the intercept, if finite
  if (!missing(intercept)) {
    normalizedData <- normalizedData + ifelse(infiniteIntercept, 0, intercept)
  }
  rownames(normalizedData) <- rownames(object)
  colnames(normalizedData) <- colnames(object)
  attr(normalizedData,"betaPriorVar") <- betaPriorVar
  if ("Intercept" %in% modelMatrixNames) {
    fittedInterceptNZ <- fit$betaMatrix[,which(modelMatrixNames == "Intercept"),drop=FALSE]
    fittedIntercept <- buildMatrixWithNARows(fittedInterceptNZ, mcols(object)$allZero)
    fittedIntercept[is.na(fittedIntercept)] <- -Inf
    attr(normalizedData,"intercept") <- fittedIntercept
  }
  normalizedData
}

sparseTest <- function(x, p, t1, t2) {
  rs <- MatrixGenerics::rowSums(x)
  rmx <- apply(x, 1, max)
  if (all(rs <= t1)) return(invisible())
  prop <- (rmx/rs)[rs > t1]
  total <- mean(prop > p)
  if (total > t2) warning("the rlog assumes that data is close to a negative binomial distribution, an assumption
which is sometimes not compatible with datasets where many genes have many zero counts
despite a few very large counts.
In this data, for ",round(total,3)*100,"% of genes with a sum of normalized counts above ",t1,", it was the case 
that a single sample's normalized count made up more than ",p*100,"% of the sum over all samples.
the threshold for this warning is ",t2*100,"% of genes. See plotSparsity(dds) for a visualization of this.
We recommend instead using the varianceStabilizingTransformation or shifted log (see vignette).")
}
