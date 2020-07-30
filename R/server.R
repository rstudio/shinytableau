tableau_server <- function(server, config_server) {
  force(server)
  force(config_server)

  # Check that server and config_server are functions and have the right params
  validate_server_function(server, "server")
  if (!is.null(config_server)) {
    validate_server_function(config_server, "config_server")
  }

  tableau_server_router <- function(input, output, session) {
    wrap_session(session)
    init_rpc(session)

    qs <- shiny::parseQueryString(shiny::isolate(session$clientData$url_search))
    if (identical(qs$mode, "embed")) {
      shiny::insertUI("body", "afterBegin", tableau_spinner(fill = TRUE), immediate = TRUE)

      o <- shiny::observe({
        # Delay loading until settings are available
        settings <- tableau_settings_all()
        shiny::req(settings)
        o$destroy()
        shiny::isolate({
          shiny::removeUI(".tableau-spinner", immediate = FALSE)
          server(input, output, session)
        })
      })
    } else if (identical(qs$mode, "configure") && is.function(config_server)) {
      shiny::insertUI("body", "afterBegin", tableau_spinner(fill = TRUE), immediate = TRUE)

      o <- shiny::observe({
        # Delay loading until settings are available
        settings <- tableau_settings_all()
        shiny::req(settings)
        o$destroy()
        shiny::isolate({
          shiny::removeUI(".tableau-spinner", immediate = FALSE)
          config_server(input, output, session)
        })
      })
    } else {
      # Do nothing
    }
  }
  tableau_server_router
}

#' Prepopulate Shiny inputs
#'
#' Call this before your Shiny inputs are created, and when they are created,
#' they will prepopulate themselves to the values contained herein. For example,
#' if you call `restore_inputs(x = 3)`, and then subsequently a
#' `numericInput("x", "x", 5)` is created, the created input will default to `3`
#' instead of `5`. Note that each call to `restore_inputs` completely replaces
#' any bookmarkable state, or previous calls to `restore_inputs`.
#'
#' `restore_inputs` is designed to be called from (the beginning of) a Shiny
#' server function, and as such, can only affect inputs created on the server
#' side (generally using `renderUI` or `insertUI`).
#'
#' @param ... Named arguments, where the names are input names (don't forget to
#'   use namespaces if you're using modules!) and the values are default values
#'   for the corresponding inputs.
#' @param session. The current Shiny session.
#'
#' @return `session.`, invisibly.
#'
#' @export
restore_inputs <- function(..., session. = shiny::getDefaultReactiveDomain()) {
  if (is.null(session.)) {
    stop("`restore_inputs` must be called from within a Shiny server function")
  }
  if (length(session.$ns(NULL)) != 0) {
    stop("`restore_inputs` must be called from within a top-level Shiny server function, not a module")
  }
  # Pretty sure Shiny always has a RestoreContext available
  stopifnot(!is.null(session.$restoreContext))

  session.$restoreContext$active <- TRUE
  session.$restoreContext$input <- shiny:::RestoreInputSet$new(rlang::list2(...))
  invisible(session.)
}

validate_server_function <- function(func, name) {
  expected_args <- c("input", "output", "session")
  valid <- is.function(func) && identical(names(formals(func)), expected_args)
  if (!valid) {
    stop("`", name, "` argument must be a function with `input`, `output`, ",
      "and `session` parameters")
  }
}
