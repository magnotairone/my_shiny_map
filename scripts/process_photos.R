library(exifr)
library(magick)
library(dplyr)
library(htmltools)
library(jsonlite)
library(tidygeocoder)

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

# ---------------- Prepare images (loop) ----------------
prepare_images <- function(files) {
  
  # pré-aloca lista (muito mais eficiente que crescer dinamicamente)
  out <- vector("list", length(files))
  
  for (i in seq_along(files)) {
    
    f <- files[i]
    base <- basename(f)
    
    thumb_path  <- file.path(www_thumbs, base)
    medium_path <- file.path(www_photos, base)
    
    # ---- Thumbnail ----
    if (!file.exists(thumb_path)) {
      try({
        image_read(f) |>
          image_scale(thumb_width) |>
          image_write(thumb_path)
      }, silent = TRUE)
    }
    
    # ---- Imagem média ----
    if (!file.exists(medium_path)) {
      try({
        image_read(f) |>
          image_scale(medium_max) |>
          image_write(medium_path)
      }, silent = TRUE)
    }
    
    # ---- Resultado da imagem i ----
    out[[i]] <- tibble(
      SourceFile = f,
      FileName   = base,
      thumb_url  = paste0("thumbs/", base),
      medium_url = paste0("photos/", base)
    )
    
    # (opcional) progresso simples
    if (i %% 50 == 0) {
      message(sprintf("Processadas %d / %d imagens", i, length(files)))
    }
  }
  
  bind_rows(out)
}



# ---------------- read json ----------------
read_google_geo <- function(image_path) {
  json_path <- paste0(image_path, ".supplemental-metadata.json")
  
  if (!file.exists(json_path)) {
    return(c(lat = NA_real_, lon = NA_real_))
  }
  
  js <- tryCatch(
    fromJSON(json_path),
    error = function(e) NULL
  )
  
  if (is.null(js) || is.null(js$geoData)) {
    return(c(lat = NA_real_, lon = NA_real_))
  }
  
  c(
    lat = js$geoData$latitude,
    lon = js$geoData$longitude
  )
}


imgs_df <- prepare_images(img_files)

# ---------------- EXIF ----------------
exif_df <- read_exif(
  imgs_df$SourceFile,
  tags = c("SourceFile", "GPSLatitude", "GPSLongitude", "DateTimeOriginal")
)


# garantir colunas
if (!"GPSLatitude" %in% names(exif_df))  exif_df$GPSLatitude  <- NA_real_
if (!"GPSLongitude" %in% names(exif_df)) exif_df$GPSLongitude <- NA_real_

# identificar linhas sem GPS
missing_gps <- is.na(exif_df$GPSLatitude) | is.na(exif_df$GPSLongitude)

if (any(missing_gps)) {
  
  google_geo <- t(
    sapply(
      exif_df$SourceFile[missing_gps],
      read_google_geo
    )
  )
  
  exif_df$GPSLatitude[missing_gps]  <- google_geo[, "lat"]
  exif_df$GPSLongitude[missing_gps] <- google_geo[, "lon"]
  
  exif_df$gps_source <- "exif"
  exif_df$gps_source[missing_gps & !is.na(google_geo[, "lat"])] <- "google_photos"
  
} else {
  exif_df$gps_source <- "exif"
}


data0 <- imgs_df |>
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

# ---------------- Add loc info ----------------

df_geo <- data0 |>
  reverse_geocode(
    lat = lat,
    long = lon,
    method = "osm",
    full_results = TRUE
  )

data <- df_geo |>
  select(names(data0), city, state, country) |>
  mutate(
    local = if_else(
      is.na(city) | city == "",
      state,
      city
    ),
    location = if_else(
      country %in% c("Brazil", "Brasil"),
      paste0(local, ", ", state),
      paste0(local, ", ", country)
    )
  )

# ---------------- Popup HTML ----------------

data <- data |>
  arrange(date) |>
  mutate(id = row_number())

data$popup_html <- paste0(
  "<div class='popup-card'>",
  
  "<div class='popup-meta'>",
  "📍 ", data$location, "<br/>",
  "📅 ", format(data$date, "%d/%m/%Y"),
  "</div>",
  
  "<div class='popup-image'>",
  "<img src='", data$thumb_url, "' />",
  "</div>",
  
  "<div class='popup-link'>",
  "<a href='#' onclick=\"Shiny.setInputValue(
        'open_photo', ", data$id, ",
        {priority: 'event'}
      ); return false;\">🔍 Ampliar imagem</a>",
  "</div>",
  
  "</div>"
)


# ---------------- Save ----------------
saveRDS(data, data_out)
data <- readRDS("data/photos_data.rds")
save(data, file = "data/data.RData")


cat("✔ Processamento concluído:", nrow(data), "fotos\n")


rm(data0, df_geo, exif_df, google_geo, imgs_df, missing_gps)

# Falta no photos:
# Milao
# Hamburgo
# Napole
# Ismir
# Riiga
# Blue Lagoon Islancia
# Montevideo

# Araxa
# Santos
# Guarapari
# Florianopolis
# Lapinha da Serra