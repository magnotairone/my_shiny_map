library(exifr)
library(magick)
library(dplyr)
library(htmltools)

# ---------------- Config ----------------
photos_dir  <- "photos"
www_photos  <- file.path("www", "photos")
www_thumbs  <- file.path("www", "thumbs")
data_out    <- file.path("data", "photos_data.rds")

thumb_width <- 120
medium_max  <- 1024

dir.create(www_photos, recursive = TRUE, showWarnings = FALSE)
dir.create(www_thumbs, recursive = TRUE, showWarnings = FALSE)
dir.create("data", recursive = TRUE, showWarnings = FALSE)

# ---------------- Files ----------------
img_files <- list.files(
  photos_dir,
  pattern = "\\.(jpe?g|png)$",
  full.names = TRUE,
  ignore.case = TRUE,
  recursive = TRUE
)

stopifnot(length(img_files) > 0)

# ---------------- Prepare images ----------------
prepare_images <- function(files) {
  bind_rows(lapply(files, function(f) {
    
    base <- basename(f)
    thumb_path  <- file.path(www_thumbs, base)
    medium_path <- file.path(www_photos, base)
    
    if (!file.exists(thumb_path)) {
      image_read(f) |>
        image_scale(thumb_width) |>
        image_write(thumb_path)
    }
    
    if (!file.exists(medium_path)) {
      image_read(f) |>
        image_scale(medium_max) |>
        image_write(medium_path)
    }
    
    tibble(
      SourceFile = f,
      FileName   = base,
      thumb_url  = paste0("thumbs/", base),
      medium_url = paste0("photos/", base)
    )
  }))
}

imgs_df <- prepare_images(img_files)

# ---------------- EXIF ----------------
exif_df <- read_exif(
  imgs_df$SourceFile,
  tags = c("SourceFile", "GPSLatitude", "GPSLongitude", "DateTimeOriginal")
)

data <- imgs_df |>
  left_join(exif_df, by = "SourceFile") |>
  filter(!is.na(GPSLatitude), !is.na(GPSLongitude)) |>
  transmute(
    lat = GPSLatitude,
    lon = GPSLongitude,
    date = as.Date(
      DateTimeOriginal,
      format = "%Y:%m:%d %H:%M:%S"
    ),
    thumb_url,
    medium_url
  )

# ---------------- Popup HTML ----------------

data$id <- seq_len(nrow(data))

data$popup_html <- paste0(
  ifelse(is.na(data$date), "", format(data$date, "%d/%m/%Y")),
  "<br/>",
  "<img src='", data$thumb_url,
  "' width='120' style='border:1px solid #ccc'/><br/>",
  "<a href='#' onclick=\"Shiny.setInputValue(
      'open_photo', ",
  data$id,
  ", {priority: 'event'}
    ); return false;\">Ampliar imagem</a>"
)

# ---------------- Save ----------------
saveRDS(data, data_out)

cat("✔ Processamento concluído:", nrow(data), "fotos\n")
