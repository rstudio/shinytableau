# filetype: shinyApp

library(shiny)
library(shinytableau)
library(DT)
library(promises)

manifest <- tableau_manifest_from_yaml()

ui <- fluidPage(
  selectInput("worksheet", "Marks for", character(0)),
  DTOutput("table")
)

server <- function(input, output, session) {
  updateSelectInput(session, "worksheet",
    choices = c("Choose worksheet" = "", tableau_worksheets()),
    selected = isolate(tableau_setting("last_worksheet", "")))

  observeEvent(input$worksheet, {
    update_tableau_settings_async(last_worksheet = input$worksheet)
  }, ignoreInit = TRUE)

  selected_data <- reactive_tableau_data(function() {
    spec_summary(req(input$worksheet))
  }, options = list(ignoreSelection = "never"))

  output$table <- renderDT({
    selected_data() %...T>%
      { validate(need(., "No marks selected")) }
  }, style = "bootstrap", class = "table table-condensed", options = list(dom = "iftrp"))
}

tableau_extension(manifest, ui, server, options = ext_options(port = 3919))
