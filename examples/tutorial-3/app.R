# filetype: shinyApp

library(shiny)
library(shinytableau)
library(promises)
library(summarytools)

manifest <- tableau_manifest_from_yaml()

ui <- function(req) {
  fluidPage(
    fluidRow(
      column(12,
        uiOutput("summary")
      )
    )
  )
}

server <- function(input, output, session) {
  df <- reactive_tableau_data("data_spec")

  output$summary <- renderUI({
    # From https://cran.r-project.org/web/packages/summarytools/vignettes/Introduction.html#creating-shiny-apps
    df() %...>%
      dfSummary(varnumbers = FALSE, valid.col = FALSE, graph.magnif = 0.8) %...>%
      print(method = "render", headings = TRUE, bootstrap.css = FALSE)
  })
}

config_ui <- function(req) {
  tagList(
    choose_data_ui("data_spec", "Choose data")
  )
}

config_server <- function(input, output, session, iv) {
  data_spec <- choose_data("data_spec", iv = iv)

  save_settings <- function() {
    update_tableau_settings_async(
      data_spec = data_spec()
    )
  }
  return(save_settings)
}

tableau_extension(manifest, ui, server, config_ui, config_server,
  options = ext_options(port = 4567)
)
