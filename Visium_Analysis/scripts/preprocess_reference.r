library(Seurat)
library(SeuratDisk)
library(SeuratData)
library(stringr)

# Transform Reference with SCT Model
transform_SCT <- function(reference_path){
  file_extension <- file_ext(reference_path)
  ref <- LoadH5Seurat(reference_path, tools = TRUE, images=FALSE)
  ref <- UpdateSeuratObject(ref)
  
  Idents(ref) <- ref$subclass.l2
  ref <- subset(ref, idents = "NA", invert = TRUE)
  
  DefaultAssay(ref) <- "RNA"
  ref <- SCTransform(
    ref,
    assay = "RNA",
    new.assay.name = "SCT",
    return.only.var.genes = FALSE,
    verbose = FALSE
  )
  
  DefaultAssay(ref) <- "SCT"
  ref <- RunPCA(ref, assay = "SCT", npcs = 50, verbose = FALSE)
  SaveH5Seurat(ref, filename = str_replace(reference_path, paste(".", file_extension, sep = ""), "_SCT.h5Seurat"))
}

arg_list <- commandArgs(trailingOnly=TRUE)
print(arg_list)
atlas_path <- gsub('\\"','',arg_list[1])
print(atlas_path)
transform_SCT(atlas_path)