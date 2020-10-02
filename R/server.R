tableau_server <- function(embed_server, config_server, standalone_server, options) {
  force(embed_server)
  force(config_server)
  force(standalone_server)
  force(options)

  # Check that server and config_server are functions and have the right params
  validate_server_function(embed_server, "embed_server")
  validate_server_function(config_server, "config_server", allowNULL = TRUE)
  validate_server_function(standalone_server, "standalone_server")

  tableau_server_router <- function(input, output, session) {
    wrap_session(session)
    init_tableau <- function() {
      init_rpc(session)
      session$sendCustomMessage("shinytableau-init", list())
    }

    mode <- mode_from_querystring(shiny::isolate(session$clientData$url_search), options)

    if (identical(mode, "embed")) {
      init_tableau()
      load_after_settings(embed_server)
    } else if (identical(mode, "configure") && is.function(config_server)) {
      init_tableau()
      load_after_settings(config_server)
    } else if (identical(mode, "standalone")) {
      standalone_server(input, output, session)
    } else {
      # Do nothing
    }
  }
  tableau_server_router
}

# Delays invocation of server_func until Tableau initialization succeeds,
# showing a progress spinner in the meantime.
load_after_settings <- function(server_func, session = shiny::getDefaultReactiveDomain()) {
  force(server_func)

  shiny::withReactiveDomain(session, {
    shiny::insertUI("body", "afterBegin", tableau_spinner(fill = TRUE), immediate = TRUE)

    # Delay loading until settings are available. Note that observeEvent will
    # not execute the body until the event expression is non-NULL.
    shiny::observeEvent(tableau_settings_all(), {
      shiny::removeUI(".tableau-spinner", immediate = FALSE)
      server_func(session$input, session$output, session)
    }, once = TRUE)
  })
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

  inputs <- rlang::list2(...)
  session.$restoreContext$set(active = TRUE, input = inputs)
  invisible(session.)
}

validate_server_function <- function(func, name, allowNULL = FALSE,
  optional_params = character(0)) {

  if (allowNULL && is.null(func)) {
    return()
  }

  func_param_names <- if (is.function(func)) names(formals(func)) else NULL
  if (!identical(func_param_names[1:3], c("input", "output", "session"))) {
    stop("`", name, "` argument must be a function with `input`, `output`, ",
      "and `session` parameters")
  }

  unexpected_params <- setdiff(func_param_names[-1:-3], optional_params)
  if (length(unexpected_params) > 0) {
    stop("`", name, "` argument had unexpected parameter(s): ",
      paste(unexpected_params, collapse = ", ")
    )
  }
}
