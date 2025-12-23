library(shiny)
library(shinyWidgets)
library(leaflet)
library(leaflet.extras)


# -----------------------------
# Dados
# -----------------------------
# data <- readRDS("data/photos_data.rds")
load("data/data.RData")

# data <- data |> 
#   filter(lat != 0, lon != 0) |> 
#   arrange(date) |>
#   mutate(id = row_number())

# data <- data[order(data$date), ]
# data$id <- seq_len(nrow(data))
data$time_num <- as.numeric(data$date)

n_photos <- nrow(data)
print(n_photos)

initial_view <- list(lng = 0, lat = 20, zoom = 2)

# -----------------------------
# UI
# -----------------------------
ui <- fluidPage(
  
  tags$head(
    tags$style(HTML("
    /* ===============================
       Variáveis de identidade visual
       =============================== */
    
    :root {
      --brand: #0b5d5b;          /* verde petróleo */
      --brand-hover: #0f766e;
      --brand-soft: #e6f2f1;
    
      --text-main: #111827;
      --text-muted: #6B7280;
    
      --border-light: #E5E7EB;
      --bg-main: #F9FAFB;
    }
    
    /* ===============================
       Layout geral
       =============================== */
    
    html, body {
      height: 100%;
      margin: 0;
      padding: 0;
    }
    
    body {
      background-color: var(--bg-main);
      font-family: -apple-system, BlinkMacSystemFont,
                   'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    }
    
    .container-fluid {
      padding-left: 0 !important;
      padding-right: 0 !important;
    }
    
    .row {
      margin-left: 0 !important;
      margin-right: 0 !important;
    }
    
    /* ===============================
       Painel lateral
       =============================== */
    
    .right-panel {
      height: 100vh;
      display: flex;
      flex-direction: column;
      padding: 16px;
      box-sizing: border-box;
    
      background-color: #ffffff;
      border-left: 3px solid var(--brand);
    }
    
    /* ===============================
       Localização
       =============================== */
    
    .photo-location {
      font-size: 17px;
      font-weight: 600;
      color: var(--brand);
      margin-bottom: 2px;
    }
    
    /* ===============================
       Data
       =============================== */
    
    .photo-date {
      font-size: 14px;
      color: var(--text-muted);
      margin-bottom: 12px;
    }
    
    /* ===============================
       Container da foto
       =============================== */
    
    .photo-container {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 4px;
    }
    
    .photo-container img {
      max-height: 100%;
      max-width: 100%;
      object-fit: contain;
    
      border-radius: 6px;
      border: 1px solid var(--border-light);
      background-color: #ffffff;
    
      box-shadow: 0 1px 4px rgba(0,0,0,0.06);
    }
    
    /* ===============================
       Meta (contador)
       =============================== */
    
    .photo-meta {
      font-size: 13px;
      color: var(--text-muted);
      margin: 8px 0;
      text-align: center;
    }
    
    /* ===============================
       Controles (botões)
       =============================== */
    
    .photo-controls .btn {
      background-color: var(--bg-main);
      border: 1px solid var(--border-light);
      color: var(--text-main);
      font-size: 16px;
    }
    
    .photo-controls .btn:hover {
      background-color: var(--brand-soft);
      border-color: var(--brand);
      color: var(--brand);
    }
    
    /* ===============================
       Slider (timeline)
       =============================== */
    
    .irs-grid-text {
      display: none;
    }
    
    .irs-grid-pol.small {
      display: none;
    }
    
    .irs-grid-pol {
      background: #9CA3AF;
      height: 10px;
    }
    
    .irs-bar {
      background: var(--brand);
    }
    
    .irs-handle {
      border-color: var(--brand);
    }
    
    .irs-single {
      background: var(--brand);
    }
    
    /* ===============================
       Transições suaves
       =============================== */
    
    * {
      transition:
        background-color 0.15s ease,
        color 0.15s ease,
        border-color 0.15s ease;
    }
    
    /* ===============================
       Popup do Leaflet
       =============================== */
    
    .leaflet-popup-content {
      width: 260px !important;
      margin: 12px;
    }
    
    /* Card */
    .popup-card {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    
    /* Meta (local + data) */
    .popup-meta {
      font-size: 13px;
      color: #555;
    }
    
    /* Imagem */
    .popup-image {
      display: flex;
      justify-content: center;
      align-items: center;
    
      max-height: 180px;
      overflow: hidden;
      border-radius: 8px;
    }
    
    .popup-image img {
      max-width: 100%;
      max-height: 180px;
      object-fit: contain;
      border-radius: 8px;
    }
    
    /* Link */
    .popup-link {
      text-align: center;
      font-size: 14px;
      font-weight: 500;
    }
    
    .popup-link a {
      color: var(--brand);
      text-decoration: none;
    }
    
    .popup-link a:hover {
      color: var(--brand-hover);
      text-decoration: underline;
    }
    ")),
    
    tags$script(HTML("
      document.addEventListener('keydown', function(e) {
        if (e.key === 'ArrowRight') {
          Shiny.setInputValue('key_next', Date.now(), {priority: 'event'});
        }
        if (e.key === 'ArrowLeft') {
          Shiny.setInputValue('key_prev', Date.now(), {priority: 'event'});
        }
      });
    ")),
    
    tags$link(
      rel = "icon",
      type = "image/png",
      href = "favicon.png"
    ),
    
    tags$title("Meu Mapa de Fotos"),
    
    tags$meta(
      name = "description",
      content = "Mapa interativo com fotos de viagens, usando geolocalização EXIF e visualização em mapa."
    ),
    
    tags$meta(
      name = "author",
      content = "Magno Severino"
    ),
    
    tags$meta(
      name = "keywords",
      content = "mapa de fotos, viagens, leaflet, shiny, R, geolocalização"
    ),
    
    tags$meta(
      name = "viewport",
      content = "width=device-width, initial-scale=1"
    ),
  ),
  
  fluidRow(
    style = "height: 100vh;",
    
    column(
      9,
      leafletOutput("map", height = "100vh"),
      style = "padding: 0;"
    ),
    
    column(
      3,
      uiOutput("photo_panel"),
      style = "padding: 0;"
    )
  ),
  
  # fluidRow(
  #   column(
  #     9,
  #     sliderInput(
  #       "time",
  #       label = NULL,
  #       min = min(data$time_num),
  #       max = max(data$time_num),
  #       value = min(data$time_num),
  #       step = 1,
  #       ticks = TRUE,
  #       width = "100%"
  #     )
  #   )
  # )
)

# -----------------------------
# Server
# -----------------------------
server <- function(input, output, session) {
  
  selected_photo <- reactiveVal(NULL)
  
  # ---- MAPA ----
  output$map <- renderLeaflet({
    leaflet(data) |>
      addTiles() |>
      setView(initial_view$lng, initial_view$lat, initial_view$zoom) |>
      addMarkers(
        lng = ~lon,
        lat = ~lat,
        popup = ~popup_html,
        layerId = ~id
      ) |>
      addEasyButton(
        easyButton(
          icon = "fa-globe",
          title = "Resetar zoom",
          onClick = JS(sprintf(
            "function(btn, map){ map.setView([%f, %f], %d); }",
            initial_view$lat,
            initial_view$lng,
            initial_view$zoom
          ))
        )
      )
  })
  
  # ---- Centralizar mapa ao mudar foto ----
  observeEvent(selected_photo(), {
    req(selected_photo())
    print(selected_photo())
    print(data$id)
    row <- data[data$id == selected_photo(), ]
    leafletProxy("map") |>
      flyTo(row$lon, row$lat, zoom = 6)
  })
  
  # ---- Clique no popup ----
  observeEvent(input$open_photo, {
    selected_photo(input$open_photo)
    updateSliderInput(session, "time", value = input$open_photo)
  })
  
  # ---- Painel lateral ----
  output$photo_panel <- renderUI({
    
    if (is.null(selected_photo())) {
      div(
        class = "right-panel",
        h4("Clique em uma foto no mapa")
      )
    } else {
      
      row <- data[data$id == selected_photo(), ]
      
      div(
        class = "right-panel",
        
        div(
          class = "photo-location",
          tags$span("📍 ", row$location)
        ),
        
        div(
          class = "photo-date",
          tags$span("📅 ", format(row$date, "%d/%m/%Y"))
        ),
        
        div(
          class = "photo-container",
          tags$img(src = row$medium_url)
        ),
        
        div(
          class = "photo-meta",
          sprintf("Foto %d de %d", selected_photo(), n_photos)
        ),
        
        div(
          class = "photo-controls",
          fluidRow(
            column(6, actionButton("prev_photo", "←", width = "100%")),
            column(6, actionButton("next_photo", "→", width = "100%"))
          )
        )
      )
    }
  })
  
  # ---- Botões ----
  observeEvent(input$next_photo, {
    new_id <- selected_photo() + 1
    if (new_id > n_photos) new_id <- 1
    selected_photo(new_id)
    updateSliderInput(session, "time", value = new_id)
  })
  
  observeEvent(input$prev_photo, {
    new_id <- selected_photo() - 1
    if (new_id < 1) new_id <- n_photos
    selected_photo(new_id)
    updateSliderInput(session, "time", value = new_id)
  })
  
  # ---- Teclado ----
  observeEvent(input$key_next, {
    new_id <- selected_photo() + 1
    if (new_id > n_photos) new_id <- 1
    selected_photo(new_id)
    updateSliderInput(session, "time", value = new_id)
  })
  
  observeEvent(input$key_prev, {
    new_id <- selected_photo() - 1
    if (new_id < 1) new_id <- n_photos
    selected_photo(new_id)
    updateSliderInput(session, "time", value = new_id)
  })
  
  # ---- Slider ----
  # observeEvent(input$time, {
  #   idx <- which.min(abs(data$time_num - input$time))
  #   selected_photo(data$id[idx])
  # }, ignoreInit = TRUE)
  
}

shinyApp(ui, server)

# library(ggplot2)
# data |> select(date, location) |> 
#   ggplot(aes(x = date, y=1, label = location)) +
#   geom_point()
