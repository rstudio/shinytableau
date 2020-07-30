# filetype: shinyApp

library(shiny)
library(shinytableau)
library(dplyr)
library(DiagrammeR)
library(visNetwork)
library(promises)

manifest <- tableau_manifest_from_yaml("manifest.yml")

ui <- function(req) {
  fillPage(
    fillCol(
      visNetworkOutput("vis", height = "100%")
    )
  )
}

server <- function(input, output, session) {
  ndf <- reactive_tableau_data(reactive(tableau_setting("ndf_spec")))
  edf <- reactive_tableau_data(reactive(tableau_setting("edf_spec")))

  output$vis <- renderVisNetwork({
    promise_all(ndf = ndf(), edf = edf()) %...>% with({
      ndf <- ndf %>% select(id, type, label, everything())
      edf <- edf %>% select(id, from, to, rel, everything())
      create_graph(nodes_df = ndf, edges_df = edf) %>%
        render_graph(output = "visNetwork")
    })
  })
}

config_ui <- function(req) {
  list(
    choose_data_ui("ndf_spec", "Choose node data"),
    choose_data_ui("edf_spec", "Choose edge data")
  )
}

config_server <- function(input, output, session, iv) {
  ndf_spec <- choose_data("ndf_spec", iv = iv)
  edf_spec <- choose_data("edf_spec", iv = iv)

  save_settings <- function() {
    update_tableau_settings_async(
      ndf_spec = ndf_spec(),
      edf_spec = edf_spec()
    )
  }

  return(save_settings)
}

tableau_extension(
  manifest, ui, server, config_ui, config_server,
  options = list(port = 2469)
)
