# filetype: shinyApp

library(shiny)
library(shinytableau)

manifest <- tableau_manifest_from_yaml()

ui <- function(req) {
  fillPage(padding = 12,
    textOutput("message", container = h2)
  )
}

server <- function(input, output, session) {
  output$message <- renderText({
    paste0("Hello, ", tableau_setting("greetee"), "!")
  })
}

config_ui <- function(req) {
  tagList(
    textInput("greetee", "Whom would you like to greet?", "world")
  )
}

config_server <- function(input, output, session) {
  save_settings <- function() {
    update_tableau_settings_async(
      greetee = input$greetee
    )
  }
  return(save_settings)
}

tableau_extension(manifest, ui, server, config_ui, config_server,
  options = ext_options(port = 3456)
)
