tableau_server <- function(server, config_server) {
  force(server)
  force(config_server)

  # Check that server and config_server are functions and have the right params
  validate_server_function(server, "server")
  if (!is.null(config_server)) {
    validate_server_function(config_server, "config_server")
  }

  tableau_server_router <- function(input, output, session) {
    qs <- parseQueryString(isolate(session$clientData$url_search))
    if (identical(qs$mode, "embed")) {
      o <- observe({
        # Delay loading until settings are available
        settings <- tableau_settings_all()
        req(settings)
        o$destroy()
        isolate({
          server(input, output, session)
        })
      })
    } else if (identical(qs$mode, "configure") && is.function(config_server)) {
      o <- observe({
        # Delay loading until settings are available
        settings <- tableau_settings_all()
        req(settings)
        o$destroy()
        isolate({
          config_server(input, output, session)
        })
      })
    } else {
      # Do nothing
    }
  }
  tableau_server_router
}

validate_server_function <- function(func, name) {
  expected_args <- c("input", "output", "session")
  valid <- is.function(func) && identical(names(formals(func)), expected_args)
  if (!valid) {
    stop("`", name, "` argument must be a function with `input`, `output`, ",
      "and `session` parameters")
  }
}
