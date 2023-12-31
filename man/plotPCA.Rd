% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plots.R
\docType{methods}
\name{plotPCA}
\alias{plotPCA}
\alias{plotPCA,DESeqTransform-method}
\title{Sample PCA plot for transformed data}
\usage{
\S4method{plotPCA}{DESeqTransform}(
  object,
  intgroup = "condition",
  ntop = 500,
  returnData = FALSE,
  pcsToUse = 1:2
)
}
\arguments{
\item{object}{a \code{\link{DESeqTransform}} object, with data in \code{assay(x)},
produced for example by either \code{\link{rlog}} or
\code{\link{varianceStabilizingTransformation}}.}

\item{intgroup}{interesting groups: a character vector of
names in \code{colData(x)} to use for grouping}

\item{ntop}{number of top genes to use for principal components,
selected by highest row variance}

\item{returnData}{should the function only return the data.frame of PC1 and PC2
with intgroup covariates for custom plotting (default is FALSE)}

\item{pcsToUse}{numeric of length 2, which PCs to plot}
}
\value{
An object created by \code{ggplot}, which can be assigned and further customized.
}
\description{
This plot helps to check for batch effects and the like.
}
\note{
See the vignette for an example of variance stabilization and PCA plots.
Note that the source code of \code{plotPCA} is very simple.
The source can be found by typing \code{DESeq2:::plotPCA.DESeqTransform}
or \code{getMethod("plotPCA","DESeqTransform")}, or
browsed on github at \url{https://github.com/mikelove/DESeq2/blob/master/R/plots.R}
Users should find it easy to customize this function.
}
\examples{

# using rlog transformed data:
dds <- makeExampleDESeqDataSet(betaSD=1)
vsd <- vst(dds, nsub=500)
plotPCA(vsd)

# also possible to perform custom transformation:
dds <- estimateSizeFactors(dds)
# shifted log of normalized counts
se <- SummarizedExperiment(log2(counts(dds, normalized=TRUE) + 1),
                           colData=colData(dds))
# the call to DESeqTransform() is needed to
# trigger our plotPCA method.
plotPCA( DESeqTransform( se ) )

}
\author{
Wolfgang Huber
}
