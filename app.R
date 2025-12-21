# app.R
# Shiny app que mapeia fotos com EXIF de GPS
# Dependências: shiny, leaflet, exifr, magick, dplyr, htmltools, readr

library(shiny)
library(leaflet)
library(exifr)
library(magick)
library(dplyr)
library(htmltools)
library(readr)

# Config
photos_dir <- "photos"      # coloque aqui o diretório com suas fotos (baixadas do álbum)
www_photos <- file.path("www", "photos")
www_thumbs <- file.path("www", "thumbs")
thumb_width <- 240         # largura do thumbnail para o popup
medium_max <- 1024         # largura máxima da imagem média (para abrir em nova aba)
drive_csv <- "data/photo_metadata_drive.csv"

# Check if Drive CSV exists
use_drive_mode <- file.exists(drive_csv)

if(use_drive_mode){
  # Drive mode: read CSV and build data frame with Drive URLs
  message("Using Drive mode: reading ", drive_csv)
  drive_data <- tryCatch({
    read_csv(drive_csv, show_col_types = FALSE)
  }, error = function(e){
    message("Error reading Drive CSV: ", e$message)
    data.frame()
  })
  
  # Filter to only rows with coordinates and DriveURL
  if(nrow(drive_data) > 0){
    data <- drive_data %>%
      filter(!is.na(lat) & !is.na(lon) & !is.na(DriveURL)) %>%
      mutate(URL = DriveURL) %>%
      select(SourceFile, FileName, URL, lat, lon, DateTimeOriginal)
    
    # Build popup_html with Drive URLs
    data$popup_html <- mapply(function(fn, dt, url){
      dt_text <- ifelse(is.na(dt) | dt == "", "", as.character(dt))
      html <- paste0(
        "<b>", htmlEscape(fn), "</b><br/>",
        if(nzchar(dt_text)) paste0(htmlEscape(dt_text), "<br/>") else "",
        "<a href='", htmlEscape(url), "' target='_blank' rel='noopener noreferrer'>",
        "<img src='", htmlEscape(url), "' width='", thumb_width, "' style='border:1px solid #ccc'/>",
        "</a><br/><small>Clique para abrir em nova aba</small>"
      )
      html
    }, data$FileName, data$DateTimeOriginal, data$URL, SIMPLIFY = FALSE)
  } else {
    data <- data.frame()
  }
} else {
  # Local mode: existing behavior
  message("Using local mode: scanning photos/ directory")
  
  dir.create(www_photos, recursive = TRUE, showWarnings = FALSE)
  dir.create(www_thumbs, recursive = TRUE, showWarnings = FALSE)
  
  # Lista de arquivos de imagens no diretório
  img_files <- list.files(photos_dir, pattern = "\\.(jpe?g|png)$", full.names = TRUE, ignore.case = TRUE, recursive = TRUE)
  
  if(length(img_files) == 0){
    message("Nenhuma imagem encontrada em 'photos/'. Coloque as fotos extraídas do álbum nessa pasta.")
  }
  
  # Função para criar thumbnail e versão média (se ainda não existir)
  prepare_images <- function(files){
    if(length(files) == 0) return(data.frame())
    df_list <- vector("list", length(files))
    for(i in seq_along(files)){
      f <- files[i]
      base <- basename(f)
      thumb_path <- file.path(www_thumbs, base)
      medium_path <- file.path(www_photos, base)
      # criar thumbnail se não existir
      if(!file.exists(thumb_path)){
        try({
          img <- image_read(f)
          img_t <- image_scale(img, paste0(thumb_width))
          image_write(img_t, path = thumb_path) # formato inferido pela extensão
        }, silent = TRUE)
      }
      # criar versão média (para abrir em nova aba) se não existir
      if(!file.exists(medium_path)){
        try({
          img <- image_read(f)
          img_m <- image_scale(img, paste0(medium_max))
          image_write(img_m, path = medium_path)
        }, silent = TRUE)
      }
      df_list[[i]] <- data.frame(SourceFile = f,
                                 FileName = base,
                                 Thumb = thumb_path,
                                 Medium = medium_path,
                                 stringsAsFactors = FALSE)
    }
    do.call(rbind, df_list)
  }
  
  if(length(img_files) > 0){
    imgs_df <- prepare_images(img_files)
    # extrair EXIF com exifr (GPSLatitude, GPSLongitude, DateTimeOriginal)
    exif_df <- tryCatch({
      read_exif(imgs_df$SourceFile, tags = c("SourceFile","GPSLatitude","GPSLongitude","DateTimeOriginal"))
    }, error = function(e){
      message("Erro lendo EXIF: ", e$message)
      data.frame(SourceFile = imgs_df$SourceFile, GPSLatitude = NA, GPSLongitude = NA, DateTimeOriginal = NA, stringsAsFactors = FALSE)
    })
    # juntar
    data <- left_join(imgs_df, exif_df, by = c("SourceFile" = "SourceFile"))
    # Filtrar somente as que têm coordenadas
    # exifr pode retornar colunas com outros nomes; aqui assumimos GPSLatitude/GPSLongitude
    if(!("GPSLatitude" %in% names(data)) | !("GPSLongitude" %in% names(data))){
      data <- data.frame() # nenhuma coordenada disponível
    } else {
      data <- data %>% filter(!is.na(GPSLatitude) & !is.na(GPSLongitude))
      names(data)[names(data) == "GPSLatitude"] <- "lat"
      names(data)[names(data) == "GPSLongitude"] <- "lon"
      data$popup_html <- mapply(function(fn, dt, thumb, medium){
        dt_text <- ifelse(is.na(dt) | dt == "", "", as.character(dt))
        thumb_url <- paste0("thumbs/", basename(thumb))
        medium_url <- paste0("photos/", basename(medium))
        html <- paste0(
          "<b>", htmlEscape(fn), "</b><br/>",
          if(nzchar(dt_text)) paste0(htmlEscape(dt_text), "<br/>") else "",
          "<a href='", htmlEscape(medium_url), "' target='_blank' rel='noopener noreferrer'>",
          "<img src='", htmlEscape(thumb_url), "' width='", thumb_width, "' style='border:1px solid #ccc'/>",
          "</a><br/><small>Clique para abrir média em nova aba</small>"
        )
        html
      }, data$FileName, data$DateTimeOriginal, data$Thumb, data$Medium, SIMPLIFY = FALSE)
    }
  } else {
    data <- data.frame()
  }
}

ui <- fluidPage(
  titlePanel("my_photo_map — Mapa de Fotos"),
  sidebarLayout(
    sidebarPanel(
      helpText("Coloque suas fotos na pasta 'photos/' (mesmo diretório do app)."),
      helpText("As fotos devem ter dados EXIF de GPS. Miniaturas serão criadas automaticamente em www/thumbs."),
      conditionalPanel(
        condition = "output.nPhotos > 0",
        verbatimTextOutput("summary")
      ),
      conditionalPanel(
        condition = "output.nPhotos == 0",
        h5("Nenhuma foto com GPS encontrada.")
      )
    ),
    mainPanel(
      leafletOutput("map", height = "800px")
    )
  )
)

server <- function(input, output, session){
  output$nPhotos <- reactive({ nrow(data) })
  outputOptions(output, "nPhotos", suspendWhenHidden = FALSE)
  output$summary <- renderText({
    paste0("Fotos mapeadas: ", nrow(data))
  })

  output$map <- renderLeaflet({
    if(nrow(data) == 0){
      leaflet() %>% addTiles() %>% setView(lng = 0, lat = 20, zoom = 2)
    } else {
      leaflet(data) %>%
        addTiles() %>%
        addMarkers(lng = ~lon, lat = ~lat,
                   popup = ~popup_html,
                   clusterOptions = markerClusterOptions())
    }
  })
}

shinyApp(ui, server)
