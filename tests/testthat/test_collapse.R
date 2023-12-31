context("collapse")
test_that("collapse replicates works", {
  dds <- makeExampleDESeqDataSet(n=10, m=8)
  dds$sample <- rep(1:4, each=2)
  dds$run <- 1:8
  dds2 <- collapseReplicates(dds, groupby=dds$sample, run=dds$run)
  expect_true(all(counts(dds2)[,1] == rowSums(counts(dds)[,1:2])))
  expect_true(dds2$runsCollapsed[1] == "1,2")

  assays(dds, withDimnames=FALSE) <- list(counts=assay(dds),
                                          foobar=matrix(runif(80),ncol=8))
  assayNames(dds)
  expect_warning(dds2 <- collapseReplicates(dds, groupby=dds$sample), "only sums")
  
})
