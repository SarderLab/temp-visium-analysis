#!/usr/bin/env Rscript
options(Ncpus = 1)
options(download.file.method = "libcurl")

fail <- function(msg) {
  message("ERROR: ", msg)
  quit(status = 1, save = "no")
}

message("R version: ", R.version.string)

ppm_cran <- "https://packagemanager.posit.co/cran/__linux__/bookworm/latest"
options(
  repos = c(CRAN = ppm_cran),
  HTTPUserAgent = sprintf(
    "R/%s R (%s)",
    getRversion(),
    paste(R.version$platform, R.version$arch, R.version$os)
  )
)
message("Using CRAN via PPM: ", getOption("repos")[["CRAN"]])

if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")

message("Setting Bioconductor version to 3.22 for R ", as.character(getRversion()))
tryCatch({
  BiocManager::install(version = "3.22", ask = FALSE, update = FALSE)
}, error = function(e) {
  fail(paste0("Failed to set Bioconductor 3.22: ", conditionMessage(e)))
})

repos <- BiocManager::repositories()
repos["CRAN"] <- ppm_cran
options(repos = repos)
message("Repos in use:")
print(getOption("repos"))

install_core <- function(pkg, version = NULL) {
  message("Installing core package: ", pkg)
  tryCatch({
    if (is.null(version)) {
      install.packages(pkg, dependencies = c("Depends", "Imports", "LinkingTo"))
    } else {
      remotes::install_version(
        pkg,
        version = version,
        dependencies = c("Depends", "Imports", "LinkingTo"),
        upgrade = "never"
      )
    }
  }, error = function(e) {
    fail(paste0("Failed to install ", pkg, ": ", conditionMessage(e)))
  })

  if (!requireNamespace(pkg, quietly = TRUE)) {
    fail(paste0("Failed to load after install: ", pkg))
  }
  message("Loaded ", pkg, " version ", as.character(packageVersion(pkg)))
}

# Seurat stack
install_core("Matrix")
install_core("SeuratObject", version = "5.2.0")
install_core("Seurat", version = "5.4.0")
install_core("Signac")

remotes::install_github("ge11232002/TFMPvalue", dependencies = TRUE, upgrade = "never")
if (!requireNamespace("TFMPvalue", quietly = TRUE)) fail("Failed to load TFMPvalue")

bioc_pkgs <- c(
  "BSgenome.Hsapiens.UCSC.hg38",
  "glmGamPoi",
  "GenomeInfoDb",
  "GenomicRanges",
  "DirichletMultinomial",
  "TFBSTools",
  "EnsDb.Hsapiens.v86",
  "IRanges",
  "Rsamtools",
  "S4Vectors"
)

for (p in bioc_pkgs) {
  message("Installing Bioconductor package: ", p)
  tryCatch({
    BiocManager::install(p, dependencies = TRUE, update = FALSE, ask = FALSE)
  }, error = function(e) {
    fail(paste0("Failed to install Bioconductor package ", p, ": ", conditionMessage(e)))
  })
  if (!requireNamespace(p, quietly = TRUE)) fail(paste0("Failed to load after install: ", p))
  message("Loaded ", p, " version ", as.character(packageVersion(p)))
}

remotes::install_github("satijalab/azimuth", dependencies = TRUE, upgrade = "never")
if (!requireNamespace("Azimuth", quietly = TRUE)) fail("Failed to load after install: Azimuth")

remotes::install_github("ctlab/fgsea",dependencies=TRUE, upgrade = "never")

remotes::install_github("JEFworks-Lab/STdeconvolve",dependencies=TRUE, upgrade = "never")
if (!requireNamespace("STdeconvolve", quietly = TRUE)) fail("Failed to load after install: STdeconvolve")


message("All R packages installed successfully.")
quit(status = 0, save = "no")