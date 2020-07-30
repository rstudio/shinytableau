# filetype: shinyApp

library(shiny)
library(shinytableau)
library(ggplot2)
library(promises)

manifest <- tableau_manifest_from_yaml("manifest.yml")

ui <- function(req) {
  fillPage(
    plotOutput("plot", height = "100%")
  )
}

server <- function(input, output, session) {
  df <- reactive_tableau_data(reactive(tableau_setting("data_spec")))

  output$plot <- renderPlot({
    plot_title <- tableau_setting("plot_title")
    xvar <- tableau_setting("xvar")
    yvar <- tableau_setting("yvar")

    df() %...>% {
      ggplot(., aes_string(x = as.symbol(xvar), y = as.symbol(yvar))) +
        geom_violin(draw_quantiles = c(0.25, 0.5, 0.75)) +
        ggtitle(plot_title)
    }
  })
}

config_ui <- function(req) {
  tagList(
    textInput("title", "Title", tableau_setting("title")),
    choose_data_ui("data", "Choose data"),
    uiOutput("var_selection_ui"),
    tableOutput("preview")
  )
}

config_server <- function(input, output, session, iv) {
  iv$add_rule("title", need, label = "Title")
  iv$add_rule("xvar", need, label = "Dimension")
  iv$add_rule("yvar", need, label = "Measure")

  data_spec <- choose_data("data", iv = iv)

  data <- reactive_tableau_data(data_spec, options = list(maxRows = 5))
  schema <- reactive_tableau_schema(data_spec)

  output$var_selection_ui <- renderUI({
    tagList(
      selectInput("xvar", "Dimension", schema()$columns$fieldName),
      selectInput("yvar", "Measure", schema()$columns$fieldName)
    )
  })

  output$preview <- renderTable({
    data()
  })

  save_settings <- function() {
    update_tableau_settings_async(
      plot_title = input$title,
      data_spec = data_spec(),
      xvar = input$xvar,
      yvar = input$yvar
    )
  }
  return(save_settings)
}

tableau_extension(
  manifest, ui, server, config_ui, config_server,
  options = ext_options(config_width = 600, config_height = 600, port = 2468)
)
