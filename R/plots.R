plotDispEsts.DESeqDataSet <- function( object, ymin, CV=FALSE,
  genecol = "black", fitcol = "red", finalcol = "dodgerblue",
  legend=TRUE, xlab, ylab, log = "xy", cex = 0.45, ... )
{
  if (missing(xlab)) xlab <- "mean of normalized counts"
  if (missing(ylab)) {
    if (CV) {
      ylab <- "coefficient of variation"
    } else {
      ylab <- "dispersion"
    }
  }
  
  px = mcols(object)$baseMean
  sel = (px>0)
  px = px[sel]

  # transformation of dispersion into CV or not
  f <- if (CV) sqrt else I
  
  py = f(mcols(object)$dispGeneEst[sel])
  if(missing(ymin))
      ymin = 10^floor(log10(min(py[py>0], na.rm=TRUE))-0.1)

  plot(px, pmax(py, ymin), xlab=xlab, ylab=ylab,
    log=log, pch=ifelse(py<ymin, 6, 20), col=genecol, cex=cex, ... )

  # use a circle over outliers
  pchOutlier <- ifelse(mcols(object)$dispOutlier[sel],1,16)
  cexOutlier <- ifelse(mcols(object)$dispOutlier[sel],2*cex,cex)
  lwdOutlier <- ifelse(mcols(object)$dispOutlier[sel],2,1)
  if (!is.null(dispersions(object))) {
    points(px, f(dispersions(object)[sel]), col=finalcol, cex=cexOutlier,
           pch=pchOutlier, lwd=lwdOutlier)
  }

  if (!is.null(mcols(object)$dispFit)) {
    points(px, f(mcols(object)$dispFit[sel]), col=fitcol, cex=cex, pch=16)
  }
  
  if (legend) {
    legend("bottomright",c("gene-est","fitted","final"),pch=16,
           col=c(genecol,fitcol,finalcol),bg="white")
  }
}

#' Plot dispersion estimates
#'
#' A simple helper function that plots the per-gene dispersion
#' estimates together with the fitted mean-dispersion relationship.
#'
#' @docType methods
#' @name plotDispEsts
#' @rdname plotDispEsts
#' @aliases plotDispEsts plotDispEsts,DESeqDataSet-method
#' 
#' @param object a DESeqDataSet, with dispersions estimated
#' @param ymin the lower bound for points on the plot, points beyond this
#'    are drawn as triangles at ymin
#' @param CV logical, whether to plot the asymptotic or biological
#' coefficient of variation (the square root of dispersion) on the y-axis.
#' As the mean grows to infinity, the square root of dispersion gives
#' the coefficient of variation for the counts. Default is \code{FALSE},
#' plotting dispersion.
#' @param genecol the color for gene-wise dispersion estimates
#' @param fitcol the color of the fitted estimates
#' @param finalcol the color of the final estimates used for testing
#' @param legend logical, whether to draw a legend
#' @param xlab xlab
#' @param ylab ylab
#' @param log log
#' @param cex cex
#' @param ... further arguments to \code{plot}
#'
#' @author Simon Anders
#'
#' @examples
#' 
#' dds <- makeExampleDESeqDataSet()
#' dds <- estimateSizeFactors(dds)
#' dds <- estimateDispersions(dds)
#' plotDispEsts(dds)
#'
#' @export
setMethod("plotDispEsts", signature(object="DESeqDataSet"), plotDispEsts.DESeqDataSet)

# Jan 2023 -- single function copied from `geneplotter` to reduce dependency count
# colors were changed for ease of viewing from red to blue
plotMA.dataframe <- function( object, ylim = NULL,
  colNonSig = "gray60", colSig = "blue", colLine = "grey40",
  log = "x", cex=0.45,
  xlab="mean of normalized counts", ylab="log fold change",
  ... ) {
  if ( !( ncol(object) == 3 & inherits( object[[1]], "numeric" ) & inherits( object[[2]], "numeric" )
    & inherits( object[[3]], "logical" ) ) ) {
    stop( "When called with a data.frame, plotMA expects the data frame
  to have 3 columns, two numeric ones for mean and log fold change,
  and a logical one for significance.")
  }
  colnames(object) <- c( "mean", "lfc", "sig" )
  object <- subset( object, mean != 0 )
  py <- object$lfc
  if ( is.null(ylim) )
    ylim <- c(-1,1) * quantile(abs(py[is.finite(py)]), probs=0.99) * 1.1
  plot(object$mean, pmax(ylim[1], pmin(ylim[2], py)),
       log=log, pch=ifelse(py<ylim[1], 6, ifelse(py>ylim[2], 2, 16)),
       cex=cex, col=ifelse( object$sig, colSig, colNonSig ), xlab=xlab, ylab=ylab, ylim=ylim, ...)
  abline( h=0, lwd=4, col=colLine )
}

plotMA.DESeqDataSet <- function(object, alpha=.1, main="",
                                xlab="mean of normalized counts", ylim,
                                colNonSig="gray60", colSig="blue", colLine="grey40",
                                returnData=FALSE,
                                MLE=FALSE, ...) {
    res <- results(object, ...)
    plotMA.DESeqResults(res, alpha=alpha, main=main, xlab=xlab, ylim=ylim, MLE=MLE)
}

plotMA.DESeqResults <- function(object, alpha, main="",
                                xlab="mean of normalized counts", ylim,
                                colNonSig="gray60", colSig="blue", colLine="grey40",
                                returnData=FALSE,
                                MLE=FALSE, ...) {

  sval <- "svalue" %in% names(object)

  if (sval) {
    test.col <- "svalue"
  } else {
    test.col <- "padj"
  }

  if (MLE) {
    if (is.null(object$lfcMLE)) {
      stop("lfcMLE column is not present: you should first run results() with addMLE=TRUE")
    }
    lfc.col <- "lfcMLE"
  } else {
    lfc.col <- "log2FoldChange"
  }
  
  if (missing(alpha)) {
    if (sval) {
      alpha <- 0.005
      message("thresholding s-values on alpha=0.005 to color points")
    } else {
      if (is.null(metadata(object)$alpha)) {
        alpha <- 0.1
      } else {
        alpha <- metadata(object)$alpha
      }
    }
  }

  isDE <- ifelse(is.na(object[[test.col]]), FALSE, object[[test.col]] < alpha)
  df <- data.frame(mean = object[["baseMean"]],
                   lfc = object[[lfc.col]],
                   isDE = isDE)

  if (returnData) {
    return(df)
  }

  if (missing(ylim)) {
    ylim <- NULL
  }

  plotMA.dataframe(
    df, ylim=ylim,
    colNonSig=colNonSig, colSig=colSig, colLine=colLine,
    xlab=xlab, main=main, ...)
}

#' MA-plot from base means and log fold changes
#'
#' A simple helper function that makes a so-called "MA-plot", i.e. a
#' scatter plot of log2 fold changes (on the y-axis) versus the mean of
#' normalized counts (on the x-axis).
#'
#' This function is essentially two lines of code: building a
#' \code{data.frame} and passing this to the \code{plotMA} method
#' for \code{data.frame}, now copied from the geneplotter package.
#' The code was modified in version 1.28 to change from red to blue points
#' for better visibility for users with color-blindness. The original plots
#' can still be made via the use of \code{returnData=TRUE} and passing the
#' resulting data.frame directly to \code{geneplotter::plotMA}.
#' The code of this function can be seen with:
#' \code{getMethod("plotMA","DESeqDataSet")}
#' If the \code{object} contains a column \code{svalue} then these
#' will be used for coloring the points (with a default \code{alpha=0.005}).
#'
#' @docType methods
#' @name plotMA
#' @rdname plotMA
#' @aliases plotMA plotMA,DESeqDataSet-method plotMA,DESeqResults-method
#' 
#' @param object a \code{DESeqResults} object produced by \code{\link{results}};
#' or a \code{DESeqDataSet} processed by \code{\link{DESeq}}, or the
#' individual functions \code{\link{nbinomWaldTest}} or \code{\link{nbinomLRT}}
#' @param alpha the significance level for thresholding adjusted p-values
#' @param main optional title for the plot
#' @param xlab optional defaults to "mean of normalized counts"
#' @param ylim optional y limits
#' @param colNonSig color to use for non-significant data points
#' @param colSig color to use for significant data points
#' @param colLine color to use for the horizontal (y=0) line
#' @param returnData logical, whether to return the data.frame used for plotting
#' @param MLE if \code{betaPrior=TRUE} was used,
#' whether to plot the MLE (unshrunken estimates), defaults to FALSE.
#' Requires that \code{\link{results}} was run with \code{addMLE=TRUE}.
#' Note that the MLE will be plotted regardless of this argument,
#' if DESeq() was run with \code{betaPrior=FALSE}. See \code{\link{lfcShrink}}
#' for examples on how to plot shrunken log2 fold changes.
#' @param ... further arguments passed to \code{plotMA} if object
#' is \code{DESeqResults} or to \code{\link{results}} if object is
#' \code{DESeqDataSet}
#'
#' @author Michael Love
#'
#' @examples
#'
#' dds <- makeExampleDESeqDataSet()
#' dds <- DESeq(dds)
#' plotMA(dds)
#' res <- results(dds)
#' plotMA(res)
#'
#' @importFrom graphics abline
#'
#' @export
setMethod("plotMA", signature(object="DESeqDataSet"), plotMA.DESeqDataSet)

#' @name plotMA
#' @rdname plotMA
#' @export
setMethod("plotMA", signature(object="DESeqResults"), plotMA.DESeqResults)

plotPCA.DESeqTransform = function(object, intgroup="condition",
                                  ntop=500, returnData=FALSE, pcsToUse=1:2)
{
  message(paste0("using ntop=",ntop," top features by variance"))
  
  # calculate the variance for each gene
  rv <- rowVars(assay(object))

  # select the ntop genes by variance
  select <- order(rv, decreasing=TRUE)[seq_len(min(ntop, length(rv)))]

  # perform a PCA on the data in assay(x) for the selected genes
  pca <- prcomp(t(assay(object)[select,]))

  # the contribution to the total variance for each component
  percentVar <- pca$sdev^2 / sum( pca$sdev^2 )

  if (!all(intgroup %in% names(colData(object)))) {
    stop("the argument 'intgroup' should specify columns of colData(dds)")
  }

  intgroup.df <- as.data.frame(colData(object)[, intgroup, drop=FALSE])
  
  # add the intgroup factors together to create a new grouping factor
  group <- if (length(intgroup) > 1) {
    factor(apply( intgroup.df, 1, paste, collapse=":"))
  } else {
    colData(object)[[intgroup]]
  }

  # assembly the data for the plot
  pcs <- paste0("PC", pcsToUse)
  d <- data.frame(V1=pca$x[,pcsToUse[1]],
                  V2=pca$x[,pcsToUse[2]],
                  group=group, intgroup.df, name=colnames(object))
  colnames(d)[1:2] <- pcs
  
  if (returnData) {
    attr(d, "percentVar") <- percentVar[pcsToUse]
    return(d)
  }

  ggplot(data=d, aes_string(x=pcs[1], y=pcs[2], color="group")) +
    geom_point(size=3) + 
    xlab(paste0(pcs[1],": ",round(percentVar[pcsToUse[1]] * 100),"% variance")) +
      ylab(paste0(pcs[2],": ",round(percentVar[pcsToUse[2]] * 100),"% variance")) +
        coord_fixed()
}

#' Sample PCA plot for transformed data
#' 
#' This plot helps to check for batch effects and the like. 
#'
#' @docType methods
#' @name plotPCA
#' @rdname plotPCA
#' @aliases plotPCA plotPCA,DESeqTransform-method
#'
#' @param object a \code{\link{DESeqTransform}} object, with data in \code{assay(x)},
#' produced for example by either \code{\link{rlog}} or
#' \code{\link{varianceStabilizingTransformation}}.
#' @param intgroup interesting groups: a character vector of
#' names in \code{colData(x)} to use for grouping
#' @param ntop number of top genes to use for principal components,
#' selected by highest row variance
#' @param returnData should the function only return the data.frame of PC1 and PC2
#' with intgroup covariates for custom plotting (default is FALSE)
#' @param pcsToUse numeric of length 2, which PCs to plot
#' 
#' @return An object created by \code{ggplot}, which can be assigned and further customized.
#' 
#' @author Wolfgang Huber
#'
#' @note See the vignette for an example of variance stabilization and PCA plots.
#' Note that the source code of \code{plotPCA} is very simple.
#' The source can be found by typing \code{DESeq2:::plotPCA.DESeqTransform}
#' or \code{getMethod("plotPCA","DESeqTransform")}, or
#' browsed on github at \url{https://github.com/mikelove/DESeq2/blob/master/R/plots.R}
#' Users should find it easy to customize this function.
#' 
#' @examples
#'
#' # using rlog transformed data:
#' dds <- makeExampleDESeqDataSet(betaSD=1)
#' vsd <- vst(dds, nsub=500)
#' plotPCA(vsd)
#'
#' # also possible to perform custom transformation:
#' dds <- estimateSizeFactors(dds)
#' # shifted log of normalized counts
#' se <- SummarizedExperiment(log2(counts(dds, normalized=TRUE) + 1),
#'                            colData=colData(dds))
#' # the call to DESeqTransform() is needed to
#' # trigger our plotPCA method.
#' plotPCA( DESeqTransform( se ) )
#'
#' @importFrom ggplot2 ggplot geom_point xlab ylab coord_fixed aes_string
#' @export
setMethod("plotPCA", signature(object="DESeqTransform"), plotPCA.DESeqTransform)

#' Plot of normalized counts for a single gene
#'
#' Normalized counts plus a pseudocount of 0.5 are shown by default.
#' 
#' @param dds a \code{DESeqDataSet}
#' @param gene a character, specifying the name of the gene to plot
#' @param intgroup interesting groups: a character vector of names in \code{colData(x)} to use for grouping.
#' Must be factor variables. If you want to plot counts over numeric, choose \code{returnData=TRUE}
#' @param normalized whether the counts should be normalized by size factor
#' (default is TRUE)
#' @param transform whether to have log scale y-axis or not.
#' defaults to TRUE
#' @param main as in 'plot'
#' @param xlab as in 'plot'
#' @param returnData should the function only return the data.frame of counts and
#' covariates for custom plotting (default is FALSE)
#' @param replaced use the outlier-replaced counts if they exist
#' @param pc pseudocount for log transform
#' @param ... arguments passed to plot
#' 
#' @examples
#'
#' dds <- makeExampleDESeqDataSet()
#' plotCounts(dds, "gene1")
#' 
#' @export
plotCounts <- function(dds, gene, intgroup="condition",
                       normalized=TRUE, transform=TRUE,
                       main, xlab="group",
                       returnData=FALSE,
                       replaced=FALSE,
                       pc, ...) {

  stopifnot(length(gene) == 1 & (is.character(gene) | (is.numeric(gene) & (gene >= 1 & gene <= nrow(dds)))))
  if (!all(intgroup %in% names(colData(dds)))) stop("all variables in 'intgroup' must be columns of colData")
  if (!returnData) {
    if (!all(sapply(intgroup, function(v) is(colData(dds)[[v]], "factor")))) {
      stop("all variables in 'intgroup' should be factors, or choose returnData=TRUE and plot manually")
    }
  }
      

  if (missing(pc)) {
    pc <- if (transform) 0.5 else 0
  }
  
  if (is.null(sizeFactors(dds)) & is.null(normalizationFactors(dds))) {
    dds <- estimateSizeFactors(dds)
  }
  cnts <- counts(dds,normalized=normalized,replaced=replaced)[gene,]
  group <- if (length(intgroup) == 1) {
    colData(dds)[[intgroup]]
  } else if (length(intgroup) == 2) {
    lvls <- as.vector(t(outer(levels(colData(dds)[[intgroup[1]]]),
                              levels(colData(dds)[[intgroup[2]]]),
                              function(x,y) paste(x,y,sep=":"))))
    droplevels(factor(apply( as.data.frame(colData(dds)[, intgroup, drop=FALSE]),
                            1, paste, collapse=":"), levels=lvls))
  } else {
    factor(apply( as.data.frame(colData(dds)[, intgroup, drop=FALSE]),
                 1, paste, collapse=":"))
  }
  data <- data.frame(count=cnts + pc, group=as.integer(group))
  logxy <- if (transform) "y" else "" 
  if (missing(main)) {
    main <- if (is.numeric(gene)) {
      rownames(dds)[gene]
    } else {
      gene
    }
  }
  ylab <- ifelse(normalized,"normalized count","count")
  if (returnData) return(data.frame(count=data$count, colData(dds)[intgroup]))
  plot(data$group + runif(ncol(dds),-.05,.05), data$count, xlim=c(.5,max(data$group)+.5),
       log=logxy, xaxt="n", xlab=xlab, ylab=ylab, main=main, ...)
  axis(1, at=seq_along(levels(group)), levels(group))
}


#' Sparsity plot
#'
#' A simple plot of the concentration of counts in a single sample over the
#' sum of counts per gene. Not technically the same as "sparsity", but this
#' plot is useful diagnostic for datasets which might not fit a negative
#' binomial assumption: genes with many zeros and individual very large
#' counts are difficult to model with the negative binomial distribution.
#'
#' @param x a matrix or DESeqDataSet
#' @param normalized whether to normalize the counts from a DESeqDataSEt
#' @param ... passed to \code{plot}
#'
#' @examples
#'
#' dds <- makeExampleDESeqDataSet(n=1000,m=4,dispMeanRel=function(x) .5)
#' dds <- estimateSizeFactors(dds)
#' plotSparsity(dds)
#' 
#' @export
plotSparsity <- function(x, normalized=TRUE, ...) {
  if (is(x, "DESeqDataSet")) {
    x <- counts(x, normalized=normalized)
  }
  rs <- MatrixGenerics::rowSums(x)
  rmx <- apply(x, 1, max)
  plot(rs[rs > 0], (rmx/rs)[rs > 0], log="x", ylim=c(0,1), xlab="sum of counts per gene",
       ylab="max count / sum", main="Concentration of counts over total sum of counts", ...)
}

# convenience function for adding alpha transparency to named colors
## col2useful <- function(col,alpha) {
##   x <- col2rgb(col)/255
##   rgb(x[1],x[2],x[3],alpha)
## }
