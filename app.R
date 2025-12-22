library(shiny)
library(shinyWidgets)
library(leaflet)
library(leaflet.extras)


# -----------------------------
# Dados
# -----------------------------
data <- readRDS("data/photos_data.rds")

data <- data[order(data$date), ]
data$id <- seq_len(nrow(data))
n_photos <- nrow(data)

initial_view <- list(lng = 0, lat = 20, zoom = 2)

# -----------------------------
# UI
# -----------------------------
ui <- fluidPage(
  
  tags$head(
    tags$style(HTML("
      .right-panel {
        height: 90vh;
        display: flex;
        flex-direction: column;
        border-left: 1px solid #ddd;
        padding: 12px;
      }

      .photo-date {
        font-size: 16px;
        font-weight: 600;
        margin-bottom: 8px;
      }

      .photo-container {
        flex: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        overflow: hidden;
      }

      .photo-container img {
        max-height: 100%;
        max-width: 100%;
        object-fit: contain;
        border: 1px solid #ccc;
      }

      .photo-controls {
        margin-top: 10px;
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
    "))
  ),
  
  fluidRow(
    column(9, leafletOutput("map", height = "calc(100vh - 70px)")),
    column(3, uiOutput("photo_panel"))
  ),
  
  fluidRow(
    column(
      9,
      sliderInput(
        "time",
        label = NULL,
        min = 1,
        max = n_photos,
        value = 1,
        step = 1,
        ticks = FALSE,
        width = "100%"
      )
    )
  )
)

# -----------------------------
# Server
# -----------------------------
server <- function(input, output, session) {
  
  selected_photo <- reactiveVal(NULL)
  print(selected_photo)
  
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
    row <- data[data$id == selected_photo(), ]
    
    div(
      class = "right-panel",
      
      div(class = "photo-date",
          format(row$date, "%d/%m/%Y")
      ),
      
      div(
        class = "photo-container",
        tags$img(src = row$medium_url)
      ),
      
      p(
        sprintf("Foto %d de %d", selected_photo(), n_photos),
        style = "color:#666;"
      ),
      
      div(
        class = "photo-controls",
        fluidRow(
          column(6, actionButton("prev_photo", "←", width = "100%")),
          column(6, actionButton("next_photo", "→", width = "100%"))
        )
      )
    )
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
  observeEvent(input$time, {
    selected_photo(input$time)
  }, ignoreInit = TRUE)
}

shinyApp(ui, server)
