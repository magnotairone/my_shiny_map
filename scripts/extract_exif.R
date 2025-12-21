# scripts/extract_exif.R
# Script opcional para extrair EXIF para CSV (útil para análises offline)
library(exifr)
library(dplyr)

photos_dir <- "photos"
out_csv <- "photo_metadata.csv"

files <- list.files(photos_dir, pattern = "\\.(jpe?g|png)$", full.names = TRUE, ignore.case = TRUE, recursive = TRUE)
if(length(files) == 0){
  stop("Nenhuma imagem encontrada em 'photos'.")
}

meta <- read_exif(files, tags = c("SourceFile","DateTimeOriginal","GPSLatitude","GPSLongitude","Model","Make"))
meta <- as.data.frame(meta)
meta <- meta %>% rename(lat = GPSLatitude, lon = GPSLongitude)
write.csv(meta, out_csv, row.names = FALSE)
message("EXIF salvo em: ", out_csv)
