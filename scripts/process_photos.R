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

# df_geo <- data0 |>
#   reverse_geocode(
#     lat = lat,
#     long = lon,
#     method = "osm",
#     full_results = FALSE
#   )

library(purrr)

df_geo <- map_dfr(seq_len(nrow(data0)), function(i) {
  Sys.sleep(1.2)  # respeita o limite do OSM
  
  reverse_geocode(
    data0[i, ],
    lat = lat,
    long = lon,
    method = "osm",
    full_results = TRUE
  )
})


# ---- Normalizar paises

library(stringr)
library(dplyr)

normalize_country <- function(country_raw) {
  
  country_clean <- str_trim(country_raw)
  
  case_when(
    
    # ----------------------------
    # Reino Unido / Irlanda
    # ----------------------------
    country_clean == "United Kingdom" ~ "Reino Unido",
    country_clean %in% c("Éire / Ireland", "Ireland", "Éire") ~ "Irlanda",
    
    # ----------------------------
    # Europa Ocidental / Central
    # ----------------------------
    country_clean == "France" ~ "França",
    country_clean %in% c("Deutschland") ~ "Alemanha",
    country_clean %in% c("Österreich") ~ "Áustria",
    country_clean %in% c("Schweiz/Suisse/Svizzera/Svizra") ~ "Suíça",
    country_clean %in% c("België / Belgique / Belgien") ~ "Bélgica",
    country_clean %in% c("Italia") ~ "Itália",
    country_clean %in% c("Danmark") ~ "Dinamarca",
    country_clean %in% c("Sverige") ~ "Suécia",
    country_clean %in% c("Ísland") ~ "Islândia",
    
    # ----------------------------
    # Europa Central / Oriental
    # ----------------------------
    country_clean %in% c("Magyarország") ~ "Hungria",
    country_clean %in% c("Česko") ~ "República Tcheca",
    country_clean %in% c("Slovensko") ~ "Eslováquia",
    country_clean %in% c("Polska") ~ "Polônia",
    country_clean %in% c("Eesti") ~ "Estônia",
    country_clean %in% c("Latvija") ~ "Letônia",
    country_clean %in% c("Malta") ~ "Malta",
    
    # ----------------------------
    # Sul / Leste da Europa
    # ----------------------------
    country_clean %in% c("Ελλάς", "Ελλάδα") ~ "Grécia",
    country_clean %in% c("Türkiye") ~ "Turquia",
    country_clean %in% c("Россия") ~ "Rússia",
    
    # ----------------------------
    # Américas
    # ----------------------------
    country_clean %in% c("Brasil", "Brazil") ~ "Brasil",
    country_clean == "Argentina" ~ "Argentina",
    country_clean == "Uruguay" ~ "Uruguai",
    country_clean %in% c("Paraguay / Paraguái") ~ "Paraguai",
    country_clean == "Chile" ~ "Chile",
    country_clean == "Colombia" ~ "Colômbia",
    country_clean == "Perú" ~ "Peru",
    country_clean == "United States" ~ "Estados Unidos",
    
    # ----------------------------
    # África
    # ----------------------------
    country_clean == "South Africa" ~ "África do Sul",
    
    # ----------------------------
    # Fallback seguro
    # ----------------------------
    TRUE ~ country_clean
  )
}

# ---- obter cidade quando nao disponivel

infer_city_from_address <- function(address, country_norm) {
  
  if (is.na(address)) return(NA_character_)
  
  parts <- str_split(address, ",")[[1]]
  parts <- str_trim(parts)
  
  # remove entradas muito longas (rua completa, regiões extensas)
  parts <- parts[nchar(parts) <= 40]
  
  # remove país
  parts <- parts[!str_detect(parts, fixed(country_norm, ignore_case = TRUE))]
  
  # remove tokens com números (rua, CEP)
  parts <- parts[!str_detect(parts, "\\d")]
  
  # heurística: segunda posição costuma ser a cidade
  if (length(parts) >= 2) {
    return(parts[2])
  }
  
  NA_character_
}


# ---- Construir localização final

df_geo <- df_geo |>
  rowwise() |>
  mutate(
    city_from_address = if_else(
      is.na(city),
      infer_city_from_address(address, country_norm),
      NA_character_
    ),
    
    # -------- popup_local --------
    popup_local = coalesce(
      city,
      city_from_address,
      neighbourhood,
      suburb,
      state,
      country_norm
    ),
    
    # -------- location (mais descritivo) --------
    location = if_else(
      country_norm %in% c("Brasil", "Brazil"),
      paste0(
        coalesce(city, city_from_address, suburb, state),
        ifelse(!is.na(state), paste0(" - ", state), "")
      ),
      paste0(
        coalesce(city, city_from_address, suburb, state),
        ", ",
        country_norm
      )
    )
  ) |>
  ungroup()


data <- df_geo |>
  select(names(data0), 
         name, suburb, city, city_from_address,
         state, country, address,
         neighbourhood) |>
  mutate(
    
    # -----------------------------
    # Parte local (name > suburb > city)
    # -----------------------------
    local_part = pmap_chr(
      list(name, suburb, city, city_from_address),
      ~ {
        parts <- c(...)
        parts <- parts[!is.na(parts) & parts != ""]
        paste(parts, collapse = ", ")
      }
    ),
    
    # -----------------------------
    # País normalizado
    # -----------------------------
    country_norm = normalize_country(country),
    
    # -----------------------------
    # Localização final
    # -----------------------------
    location = case_when(
      
      # Brasil
      country_norm == "Brasil" & local_part != "" & !is.na(state) ~
        paste0(local_part, ", ", state),
      
      country_norm == "Brasil" & local_part != "" ~
        local_part,
      
      # Fora do Brasil
      country_norm != "Brasil" & local_part != "" ~
        paste0(local_part, ", ", country_norm),
      
      # Fallback extremo
      TRUE ~ country_norm
    ),
    
    popup_local = coalesce(
      city,
      city_from_address,
      neighbourhood,
      suburb,
      state,
      country_norm
    )
  ) |>
  select(-local_part)

# ---------------- Popup HTML ----------------

data <- data |>
  arrange(date) |>
  mutate(id = row_number())

# data$popup_html <- paste0(
#   "<div class='popup-card'>",
#   
#   "<div class='popup-meta'>",
#   "📍 ", data$location, "<br/>",
#   "📅 ", format(data$date, "%d/%m/%Y"),
#   "</div>",
#   
#   "<div class='popup-image'>",
#   "<img src='", data$thumb_url, "' />",
#   "</div>",
#   
#   "<div class='popup-link'>",
#   "<a href='#' onclick=\"Shiny.setInputValue(
#         'open_photo', ", data$id, ",
#         {priority: 'event'}
#       ); return false;\">🔍 Ampliar imagem</a>",
#   "</div>",
#   
#   "</div>"
# )

country_flag <- c(
  "Brasil" = "🇧🇷",
  "Argentina" = "🇦🇷",
  "Uruguai" = "🇺🇾",
  "Paraguai" = "🇵🇾",
  "Chile" = "🇨🇱",
  "Estados Unidos" = "🇺🇸",
  "Reino Unido" = "🇬🇧",
  "Irlanda" = "🇮🇪",
  "França" = "🇫🇷",
  "Alemanha" = "🇩🇪",
  "Áustria" = "🇦🇹",
  "Suíça" = "🇨🇭",
  "Bélgica" = "🇧🇪",
  "Itália" = "🇮🇹",
  "Dinamarca" = "🇩🇰",
  "Suécia" = "🇸🇪",
  "Islândia" = "🇮🇸",
  "Hungria" = "🇭🇺",
  "República Tcheca" = "🇨🇿",
  "Eslováquia" = "🇸🇰",
  "Polônia" = "🇵🇱",
  "Estônia" = "🇪🇪",
  "Letônia" = "🇱🇻",
  "Malta" = "🇲🇹",
  "Grécia" = "🇬🇷",
  "Turquia" = "🇹🇷",
  "Rússia" = "🇷🇺",
  "África do Sul" = "🇿🇦"
)


data$popup_html <- paste0(
  "<div class='popup-card'>",
  
  "<div class='popup-meta'>",
  "📍 ", data$popup_local, "<br/>",
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


# rm(data0, df_geo, exif_df, google_geo, imgs_df, missing_gps)

# Falta no photos:
# Milao
# Hamburgo
# Blue Lagoon Islancia
# Montevideo

# Santos
# Guarapari
# Lapinha da Serra
