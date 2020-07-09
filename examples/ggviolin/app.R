options(shiny.port = 2468)

library(shiny)
library(shinytableau)
library(ggplot2)
library(promises)

timestamp <- function() {
  absolutePanel(bottom = 0, right = 0,
    style = htmltools::css(
      opacity = 0.6,
      background_color = "black",
      color = "white",
      font_size = "10px",
      padding = "3px 6px"
    ),
    "This page was loaded at ",
    Sys.time()
  )
}

# TODO: yaml file?
manifest <- tableau_manifest(
  #source_location = "https://jcheng.shinyapps.io/tableautest/?mode=embed",
  extension_id = "com.example.ggviolin",
  extension_version = "1.1.3",
  name = "Violin Plot",
  description = "Insert a violin plot using ggplot2",
  extended_description = tagList(
    tags$p("This is an extension for Tableau dashboards that enables the easy creation of violin plots.")
  ),
  author_name = "Jane Doe",
  author_email = "jane_doe@example.com",
  author_organization = "Example Corp.",
  website = "https://example.com/tableau/extensions/ggviolin"
)

ui <- function(req) {
  fillPage(
    fillCol(
      plotOutput("plot", height = "100%")
    )
    #timestamp()
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
        geom_violin() +
        ggtitle(plot_title)
    }
  })
}

config_ui <- fillPage(
  fillCol(flex = c(1, NA),
    miniUI::miniContentPanel(
      textInput("title", "Title", ""),
      choose_data_ui("data", "Choose data"),
      uiOutput("x_ui"),
      uiOutput("y_ui")
    ),
    htmltools::tags$div(style = "text-align: right; padding: 8px 15px; height: 50px; border-top: 1px solid #DDD;",
      actionButton("ok", "OK", class = "btn-primary"),
      actionButton("cancel", "Cancel"),
      actionButton("apply", "Apply")
    )
  )
)

config_server <- function(input, output, session) {
  data_spec <- choose_data("data")

  data <- reactive_tableau_data(data_spec, options = list(maxRows = 3))

  output$x_ui <- renderUI({
    data() %...>% (function(df) {
      selectInput("xvar", "x-variable", names(df))
    })
  })

  output$y_ui <- renderUI({
    data() %...>% (function(df) {
      selectInput("yvar", "y-variable", names(df))
    })
  })

  save_settings <- function() {
    update_tableau_settings(
      plot_title = input$title,
      data_spec = data_spec(),
      xvar = req(input$xvar),
      yvar = req(input$yvar),
      save. = TRUE
    )
  }

  observeEvent(input$ok, {
    save_settings()
    tableau_close_dialog()
  })
  observeEvent(input$cancel, {
    tableau_close_dialog()
  })
  observeEvent(input$apply, {
    save_settings()
  })
}

tableau_extension(manifest, ui, server, config_ui, config_server)
