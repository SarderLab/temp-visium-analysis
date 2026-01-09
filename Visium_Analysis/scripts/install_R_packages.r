#!/usr/bin/env Rscript
options(repos = c(CRAN = "https://cran.rstudio.com/"))
options(Ncpus = 1)

fail <- function(msg) {
  message("ERROR: ", msg)
  quit(status = 1, save = "no")
}

# Ensure bootstrap installers exist
# if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")

bioc_pkgs <- c(
  "BSgenome.Hsapiens.UCSC.hg38",
  "glmGamPoi",
  "GenomeInfoDb",
  "GenomicRanges",
  "EnsDb.Hsapiens.v86",
  "IRanges",
  "Rsamtools",
  "S4Vectors"
)

for (p in bioc_pkgs) {
  message("Installing Bioc package: ", p)
  BiocManager::install(p, dependencies = TRUE, update = FALSE, ask = FALSE)
  if (!requireNamespace(p, quietly = TRUE)) fail(paste0("Failed to load after install: ", p))
}

message("All R packages installed successfully.")
quit(status = 0, save = "no")