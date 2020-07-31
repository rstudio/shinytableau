# TODO: Errors are thrown by Tableau if no worksheet has data
# TODO: Show message on initial load if configuration is required
# TODO: Show progress indicators on initial load and recalculation
# TODO: Remove miniUI dependency
# TODO: reactive_tableau_data equivalent for accessing schemas; will let us get
#   rid of async in ggviolin config_server
# TODO: Allow opt-out of various features: config dialog boilerplate, "please
#   configure" message, auto-bookmarkable state

# Wraps manifest, ui, and config_ui, which are conceptually three totally
# separate things, into a single ui function for shinyApp to consume. This
# relies on the querystring to determine what mode the request is intended for.
tableau_ui <- function(manifest, ui, config_ui, options = ext_options()) {
  force(manifest)
  force(ui)
  force(config_ui)

  trex_initialized <- FALSE

  function(req) {
    qs <- shiny::parseQueryString(req[["QUERY_STRING"]])
    mode <- qs[["mode"]]
    if (identical(mode, "embed")) {
      tagList(
        # Create metadata script block for our JS to consume
        tags$head(tags$script(id = "tableau-ext-config", type = "application/json",
          jsonlite::toJSON(auto_unbox = TRUE, list(
            config_width = options[["config_width"]],
            config_height = options[["config_height"]]
          ))
        )),
        display_with_deps(ui, req)
      )
    } else if (identical(mode, "configure")) {
      if (!is.null(config_ui)) {
        display_with_deps(config_ui, req)
      } else {
        "This extension has no settings to configure"
      }
    } else if (identical(mode, "trex")) {
      trex_handler(req, manifest, !is.null(config_ui))
    } else {
      welcome_ui(manifest)
    }
  }
}

display_with_deps <- function(ui, req) {
  if (is.function(ui)) {
    ui <- ui(req)
  }

  return(htmltools::tagList(
    shinytableau::shinytableau_lib(),
    ui
  ))
}

welcome_ui <- function(manifest) {
  trexfilename <- paste0(manifest[["name"]], ".trex")

  htmltools::tagList(
    htmltools::includeCSS(system.file("welcome/welcome.css", package = "shinytableau")),
    htmltools::htmlTemplate(system.file("welcome/welcome.html", package = "shinytableau"),
      manifest = manifest,
      trexfilename = trexfilename,
      author = author_html(manifest),
      document_ = FALSE)
  )
}

author_html <- function(manifest) {
  name <- manifest[["author_name"]]
  email <- manifest[["author_email"]]
  org <- manifest[["author_organization"]]

  author <- name
  if (!is.null(email)) {
    author <- htmltools::tags$a(
      href = paste0("mailto:", email),
      title = email,
      name
    )
  }
  if (!is.null(org)) {
    author <- htmltools::tagList(author,
      paste0(" (", org, ")")
    )
  }
  author
}

#' @export
tableau_close_dialog <- function(payload = "", session = shiny::getDefaultReactiveDomain()) {
  session <- unwrap_session(session)
  session$sendCustomMessage("shinytableau-close-dialog", list(payload = payload))
}
