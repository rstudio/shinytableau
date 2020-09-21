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
tableau_ui <- function(manifest, embed_ui, config_ui, standalone_ui, options = ext_options()) {
  force(manifest)
  force(embed_ui)
  force(config_ui)
  force(standalone_ui)
  force(options)

  trex_initialized <- FALSE

  function(req) {
    mode <- mode_from_querystring(req[["QUERY_STRING"]], options)

    if (identical(mode, "embed")) {
      htmltools::tagList(
        # Create metadata script block for our JS to consume
        htmltools::tags$head(htmltools::tags$script(id = "tableau-ext-config", type = "application/json",
          jsonlite::toJSON(auto_unbox = TRUE, list(
            config_width = options[["config_width"]],
            config_height = options[["config_height"]]
          ))
        )),
        display_with_deps(embed_ui, req)
      )
    } else if (identical(mode, "configure")) {
      if (!is.null(config_ui)) {
        display_with_deps(config_ui, req)
      } else {
        "This extension has no settings to configure"
      }
    } else if (identical(mode, "trex")) {
      trex_handler(req, manifest, !is.null(config_ui))
    } else if (identical(mode, "info")) {
      display_with_deps(welcome_ui(manifest), req)
    } else if (identical(mode, "standalone")) {
      display_with_deps(standalone_ui, req)
    }
  }
}

display_with_deps <- function(ui, req) {
  if (is.function(ui)) {
    ui <- ui(req)
  }

  return(htmltools::tagList(
    shinytableau_lib(),
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

#' Close Tableau extension's configuration dialog
#'
#' Invoke from within `config_server` function to close the configuration
#' dialog. Most extensions should not need to call this, as shinytableau will
#' automatically call it when the configuration dialog's OK or Cancel buttons
#' are pressed.
#'
#' @param payload Not currently used by shinytableau.
#' @param session The Shiny `session` object. (You should probably just use the
#'   default.)
#'
#' @export
tableau_close_dialog <- function(payload = "", session = shiny::getDefaultReactiveDomain()) {
  session <- unwrap_session(session)
  session$sendCustomMessage("shinytableau-close-dialog", list(payload = payload))
}

#' Create a hyperlink to embedding instructions
#'
#' Use this function to create a link that [`standalone = TRUE`][ext_options]
#' apps can present in their UI, that will bring the user to the Tableau
#' extension information page (where the manifest information and .trex file
#' download button are found).
#'
#' @param ... Attributes and children of the element; these are passed through
#'   to [htmltools::a()].
#' @param target The value of the `target` attribute. The default value of
#'   `"_blank"` will cause the link to open in a new browser tab or window. Pass
#'   `NULL` or `"_self"` instead to open in the current frame, or `"_top"` to
#'   use the current browser tab but to break out of any iframe.
#' @param button If `"primary"` or `"default"`, Bootstrap CSS classes will be
#'   added to make the link look like a button.
#'
#' @return An HTML object, suitable for including in Shiny UI.
#'
#' @seealso You can use [tableau_is_embedded()] to prevent the link from
#'   appearing if we're already running in a Tableau dashboard. See the example
#'   below.
#'
#' @examples
#' ui <- function(req) {
#'   fluidPage(
#'
#'     # If we're not currently running in a Tableau dashboard, insert a link
#'     if (!tableau_is_embedded()) {
#'       absolutePanel(top = 10, right = 10,
#'         tableau_install_link("Embed this app in Tableau!")
#'       )
#'     },
#'
#'     # Other UI...
#'   )
#' }
#'
#' @export
tableau_install_link <- function(..., target = "_blank", button = c("no", "primary", "default")) {
  button <- match.arg(button)
  button_class <- switch(button,
    primary = "btn btn-primary",
    default = "btn btn-default",
    NULL
  )

  htmltools::a(href = "?mode=info", target = target, class = button_class, ...)
}

#' Determine whether a standalone app is running in Tableau
#'
#' For extensions that use [`ext_options(standalone = TRUE)`][ext_options], the
#' `ui` and `server` objects are invoked in both standalone mode (outside of a
#' Tableau dashboard) and embedded mode (inside a dashboard). The
#' `tableau_is_embedded()` function can be used to distinguish between the two
#' cases, in case you want to vary the UI elements and/or behavior for each.
#'
#' @return `TRUE` if running in Tableau, `FALSE` if not or if it cannot be
#'   determined.
#'
#' @export
tableau_is_embedded <- function() {
  session <- shiny::getDefaultReactiveDomain()
  if (is.null(session)) {
    FALSE
  } else {
    qs <- shiny::isolate(shiny::parseQueryString(shiny::getDefaultReactiveDomain()$clientData$url_search))
    identical(qs[["mode"]], "embed")
  }
}
