options(shiny.port = 2468)

library(shiny)
library(shinytableau)
library(corrr)
library(ggplot2)
library(promises)

# TODO: yaml file?
manifest <- tableau_manifest(
  #source_location = "https://jcheng.shinyapps.io/tableautest/?mode=embed",
  extension_id = "com.example.corrr",
  extension_version = "1.1.3",
  name = "corrr",
  description = "Create a correlation plot based on a single dataset",
  extended_description = tagList(
    tags$p("This is an extension for Tableau dashboards that creates a correlation matrix visualization.")
  ),
  author_name = "Jane Doe",
  author_email = "jane_doe@example.com",
  author_organization = "Example Corp.",
  website = "https://example.com/tableau/extensions/corrr"
)

ui <- function(req) {
  fillPage(
    fillCol(
      plotOutput("plot", height = "100%")
    )
  )
}

server <- function(input, output, session) {
  df <- reactive_tableau_data(reactive(tableau_setting("data_spec")))

  output$plot <- renderPlot({

    df() %...>% {

      numeric_cols <- vapply(., FUN.VALUE = logical(1), FUN = is.numeric)

      corrr::rplot(corrr::correlate(x = .[, numeric_cols, drop = FALSE], quiet = TRUE)) +
        ggplot2::theme(
          axis.text.x = ggplot2::element_text(
            angle = 90, vjust = 0.5, hjust = 1
          ),
          text = ggplot2::element_text(
            size = 16, face = "bold"
          )
        )
    }
  })
}

config_ui <- fillPage(
  fillCol(flex = c(1, NA),
    miniUI::miniContentPanel(
      textInput("title", "Title", ""),
      choose_data_ui("data", "Choose data"),
      tableOutput("preview")
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

  output$preview <- renderTable({
    data()
  })

  save_settings <- function() {
    update_tableau_settings(
      plot_title = input$title,
      data_spec = data_spec(),
      save. = TRUE
      # TODO: add. = FALSE
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
