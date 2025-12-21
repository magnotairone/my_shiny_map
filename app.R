library(shiny)
library(leaflet)

data <- readRDS("data/photos_data.rds")

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      .right-panel {
        border-left: 1px solid #ddd;
        padding-left: 15px;
        height: 100vh;
        overflow-y: auto;
      }
    "))
  ),
  
  fluidRow(
    column(9, leafletOutput("map", height = "100vh")),
    column(3, div(class = "right-panel", uiOutput("photo_panel")))
  )
)



server <- function(input, output, session){
  
  output$summary <- renderText({
    paste("Fotos mapeadas:", nrow(data))
  })
  
  output$map <- renderLeaflet({
    leaflet(data) |>
      addTiles() |>
      addMarkers(
        lng = ~lon,
        lat = ~lat,
        popup = ~popup_html,
        clusterOptions = markerClusterOptions()
      )
  })
  
  selected_photo <- reactiveVal(NULL)
  
  observeEvent(input$open_photo, {
    selected_photo(input$open_photo)
  })
  
  output$photo_panel <- renderUI({
    
    id <- selected_photo()
    
    if (is.null(id)) {
      h4("Clique em “Ampliar imagem” em uma foto")
    } else {
      
      row <- data[data$id == id, ]
      
      tagList(
        h4(format(row$date, "%d/%m/%Y")),
        tags$img(
          src = row$medium_url,
          style = "width:100%; border:1px solid #ccc;"
        )
      )
    }
  })
  
  
}

shinyApp(ui, server)
