## Running cell deconvolution methods
library(Seurat)
library(stringr)
library(SeuratDisk)
library(Azimuth)
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

# Function for integration using KPMP atlas
integrate_kpmp_atlas <- function(spatial, atlas_path){
    DefaultAssay(spatial) <- "SCT"
    
    spatial = DietSeurat(
      spatial,
      assays = "SCT",
      layers = NULL,
      dimreducs = c("pca"), 
      graphs = NULL
    )
    gc()
    
    kpmp_atlas <- LoadH5Seurat(atlas_path, tools = TRUE, images=FALSE)
    kpmp_atlas <- UpdateSeuratObject(kpmp_atlas)
    DefaultAssay(kpmp_atlas) <- "SCT"
    
    kpmp_atlas <- DietSeurat(
      kpmp_atlas,
      assays = c("RNA", "SCT"),
      layers = NULL,
      dimreducs = c("pca"), 
      graphs = NULL
    )
    gc()

    keep <- !is.na(kpmp_atlas$subclass.l2) & kpmp_atlas$subclass.l2 != "NA" & !is.na(kpmp_atlas$subclass.l1) & kpmp_atlas$subclass.l1 != "NA"
    kpmp_atlas <- kpmp_atlas[, keep, drop = FALSE]

    anchors <- FindTransferAnchors(
        reference = kpmp_atlas,
        query = spatial,
        normalization.method = "SCT",
        query.assay = "SCT",
        reference.assay = "SCT",
        recompute.residuals = FALSE,
        dims = 1:30
    )
    gc()


    predictions.assay <- TransferData(
        anchorset = anchors, refdata = kpmp_atlas@meta.data[["subclass.l2"]],
        prediction.assay = TRUE,
        weight.reduction = spatial[["pca"]], dims = 1:30
    )
    
    spatial[["pred_subclass_l2"]] <- predictions.assay

    df_pred <- predictions.assay@data
    max_pred <- apply(df_pred, 2, function(x) max.col(t(x),"first"))
    max_pred_val <- apply(df_pred, 2, function(x) max(t(x)))
    max_pred <- as.data.frame(max_pred)
    max_pred$Seurat_subset <- rownames(df_pred)[max_pred$max_pred]
    max_pred$score <- max_pred_val
    max_pred$Barcode <- rownames(max_pred)

    spatial@meta.data$subclass.l2 <- max_pred$Seurat_subset
    spatial@meta.data$subclass.l2_score <- max_pred$score
    gc()
    
    predictions.assay <- TransferData(
        anchorset = anchors, 
        refdata = kpmp_atlas@meta.data[["subclass.l1"]],
        prediction.assay = TRUE,
        weight.reduction = spatial[["pca"]],
        dims = 1:30
    )

    spatial[["pred_subclass_l1"]] <- predictions.assay

    df_pred <- predictions.assay@data
    max_pred <- apply(df_pred, 2, function(x) max.col(t(x), "first"))
    max_pred_val <- apply(df_pred,2, function(x) max(t(x)))

    max_pred <- as.data.frame(max_pred)
    max_pred$Seurat_subset <- rownames(df_pred)[max_pred$max_pred]
    max_pred$score <- max_pred_val
    max_pred$Barcode <- rownames(max_pred)

    spatial@meta.data$subclass.l1 <- max_pred$Seurat_subset
    spatial@meta.data$subclass.l1_score <- max_pred$score
    gc()

    return(spatial)
}


# General function for getting deconvolution results
get_label_transfer <- function(input_file, organ_key, atlas_path){
    # Reading input file
    read_input_file <- read_data_formats(input_file)
    file_extension <- file_ext(input_file)
    if (!is.na(organ_key)) {
      if (organ_key == "kidneykpmp"){
        print("Using KPMP Reference")
        integrated_spatial_data <- integrate_kpmp_atlas(read_input_file, atlas_path)
      } else {
        integrated_spatial_data <- RunAzimuth(read_input_file, organ_key)
      }
      
      output_path <- str_replace(input_file,paste(".",file_extension,sep=""),'_integrated.rds')
      saveRDS(integrated_spatial_data,output_path)  
    }
}

arg_list <- commandArgs(trailingOnly=TRUE)
print(arg_list)
input_file <- gsub('\\"','',arg_list[1])
organ_key <- gsub('\\"','',arg_list[2])
atlas_path <- gsub('\\"','',arg_list[3])
print(input_file)
print(organ_key)
print(atlas_path)
get_label_transfer(input_file,organ_key,atlas_path)