# TODO: Validation of config settings
# TODO: Config settings do not default to currently-saved state
# TODO: Errors are thrown by Tableau if no worksheet has data

# Wraps manifest, ui, and config_ui, which are conceptually three totally
# separate things, into a single ui function for shinyApp to consume. This
# relies on the querystring to determine what mode the request is intended for.
tableau_ui <- function(manifest, ui, config_ui) {
  force(manifest)
  force(ui)
  force(config_ui)

  trex_initialized <- FALSE

  function(req) {
    qs <- shiny::parseQueryString(req[["QUERY_STRING"]])
    mode <- qs[["mode"]]
    if (identical(mode, "embed")) {
      display_with_deps(ui, req)
    } else if (identical(mode, "configure")) {
      if (!is.null(config_ui)) {
        display_with_deps(config_ui, req, TRUE)
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

display_with_deps <- function(x, req, react = FALSE) {
  if (is.function(x)) {
    return(htmltools::tagList(
      if (react) reactR::html_dependency_react(),
      shinytableau::shinytableau_lib(),
      x(req)
    ))
  } else {
    return(htmltools::tagList(
      if (react) reactR::html_dependency_react(),
      shinytableau::shinytableau_lib(),
      x
    ))
  }
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
