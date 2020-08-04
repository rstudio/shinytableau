embed_ui_template <- function() {
  ns <- shiny::NS(c("shinytableau", "embed"))

  shiny::uiOutput(ns("body"), container = htmltools::tags$body)
}

tableau_embed_server <- function(manifest, ui, server_func) {
  force(server_func)
  if (is.function(ui)) {
    ui_func <- ui
  } else {
    ui_func <- function(req) { ui }
  }

  ns <- shiny::NS(c("shinytableau", "embed"))

  function(input, output, session) {
    output[[ns("body")]] <- shiny::renderUI({
      has_settings <- shiny::isolate(length(tableau_settings_all()) > 0)
      if (!has_settings) {
        # Take reactive dependency on settings
        tableau_settings_all()

        return(needs_config_ui(manifest))
      } else {
        result <- shiny::isolate({
          ui_func(session$request)
        })
        maskReactiveContext(server_func(input, output, session))
        result
      }
    })
  }
}

needs_config_ui <- function(manifest) {
  htmltools::tagList(
    htmltools::includeCSS(system.file("welcome/welcome.css", package = "shinytableau")),
    htmltools::h1(id = "name",
      manifest[["name"]],
      htmltools::tags$small(manifest[["extension_version"]])
    ),
    htmltools::div(class = "alert-warning",
      "This extension object hasn't been configured yet. Click the ",
      tags$code("More Options"),
      " down-arrow on this object, and select ",
      tags$code("Configure", .noWS = "after"), "."
    )
  )
}
