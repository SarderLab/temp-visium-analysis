## Running cell deconvolution methods
library(Seurat)
library(STdeconvolve)
library(stringr)
library(SeuratDisk)
library(SeuratData)
library(patchwork)
library(dplyr)
library(tools)
options(timeout=300)

# Function for reading in different types of counts files
read_data_formats <- function(input_file_path){
    file_extension <- file_ext(input_file_path)
    print(input_file_path)
    print(file_extension)
    if (!is.na(file_extension)){
      if (tolower(file_extension) == "rds"){
        read_file <- readRDS(input_file_path)
      } else if (tolower(file_extension) == "h5"){
        read_file <- Read10X_h5(input_file_path)
        read_file <- CreateSeuratObject(counts = read_file)
      } else if (tolower(file_extension) == "h5ad"){
        read_file <- LoadH5Seurat(input_file_path)
      }
      return(read_file)  
    }
}

# Function for running STdeconvolve
RunSTDeconvolve <- function(read_input_file){
    counts <- read_input_file@assays[[read_input_file@active.assay]]$counts

    # Using default parameters from their GitHub
    counts <- cleanCounts(counts,min.lib.size=100)
    ## feature select for genes
    corpus <- restrictCorpus(counts,removeAbove=1.0,removeBelow=0.05)
    ## choose optimal number of cell-types
    ldsas <- fitLDA(t(as.matrix(corpus)),Ks=seq(2,9,by=1))
    ## getting best model results
    optLDA <- optimalModel(models=ldsas,opt="min")
    ## extract deconvolved cell-type proportions (theta) and transcriptional profiles (beta)
    results <- getBetaTheta(optLDA,perc.filt = 0.05, betaScale = 1000)
    deconProp <- results$theta
    deconGexp <- results$beta

    # Modifying column names in deconProp
    colnames(deconProp) <- lapply(colnames(deconProp),function(i){paste("ST Topic",i,sep=" ")})

    read_input_file@assays[["stdeconvolve_results"]] <- CreateAssayObject(data=deconProp)

    return(read_input_file)
}

# General function for getting deconvolution results
get_cell_deconvolution <- function(input_file){
    # Reading input file
    read_input_file <- read_data_formats(input_file)
    file_extension <- file_ext(input_file)
    if (!is.na(file_extension)){
      print("Using STdeconvolve")
      integrated_spatial_data <- RunSTDeconvolve(read_input_file)
      
      output_path <- str_replace(input_file,paste(".",file_extension,sep=""),'_integrated.rds')
      saveRDS(integrated_spatial_data,output_path)  
    }
}

arg_list <- commandArgs(trailingOnly=TRUE)
print(arg_list)
input_file <- gsub('\\"','',arg_list[1])
print(input_file)
get_cell_deconvolution(input_file)

