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

config_ui <- fillPage(
  fillCol(flex = c(1, NA),
    miniUI::miniContentPanel(
      fillRow(height = "auto",
        choose_data_ui("ndf_spec", "Choose node data"),
        choose_data_ui("edf_spec", "Choose edge data")
      )
    ),
    htmltools::tags$div(style = "text-align: right; padding: 8px 15px; height: 50px; border-top: 1px solid #DDD;",
      actionButton("ok", "OK", class = "btn-primary"),
      actionButton("cancel", "Cancel"),
      actionButton("apply", "Apply")
    )
  )
)

config_server <- function(input, output, session) {

  restore_inputs(
    !!!choose_data_unpack("ndf_spec"),
    !!!choose_data_unpack("edf_spec")
  )

  ndf_spec <- choose_data("ndf_spec")
  edf_spec <- choose_data("edf_spec")

  save_settings <- function() {
    update_tableau_settings(
      ndf_spec = ndf_spec(),
      edf_spec = edf_spec(),
      save. = TRUE
      # TODO: add. = FALSE
    )
  }

  test <- function(expr, default_message) {
    tryCatch({expr; NULL},
      shiny.silent.error = function(err) { default_message },
      validation = function(err) { conditionMessage(err) }
    )
  }

  validate <- function() {
    message <- NULL
    if (!is.null(message)) message <- test(ndf_spec(), "Please specify node data")
    if (!is.null(message)) message <- test(edf_spec(), "Please specify edge data")
    if (!is.null(message)) {
      showModal(modalDialog(message, title = "Error"))
      FALSE
    } else {
      TRUE
    }
  }

  observeEvent(input$ok, {
    if (validate()) {
      save_settings()
      tableau_close_dialog()
    }
  })
  observeEvent(input$cancel, {
    tableau_close_dialog()
  })
  observeEvent(input$apply, {
    if (validate()) {
      save_settings()
    }
  })
}

tableau_extension(
  manifest, ui, server, config_ui, config_server,
  options = list(port = 2469)
)
