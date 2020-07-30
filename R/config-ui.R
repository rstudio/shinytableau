config_ui_template <- function() {
  ns <- NS(c("shinytableau", "config"))

  fillPage(
    fillCol(flex = c(1, NA),
      miniUI::miniContentPanel(
        uiOutput(ns("ui"))
      ),
      htmltools::tags$div(style = "text-align: right; padding: 8px 15px; height: 50px; border-top: 1px solid #DDD;",
        uiOutput(ns("footer_ui"))
      )
    )
  )
}

tableau_config_server <- function(ui_func, server_func) {
  force(ui_func)
  force(server_func)

  ns <- NS(c("shinytableau", "config"))

  function(input, output, session) {
    # TODO: Set up restore context

    isolate({
      bookmark_url <- tableau_setting("shinytableau_ui_state")
      tryCatch(
        {
          if (!is.null(bookmark_url)) {
            parts <- strsplit(bookmark_url, "?", fixed = TRUE)[[1]]
            if (length(parts) == 2) {
              qs <- parseQueryString(parts[[2]])
              qs[["_inputs_"]] <- NULL
              qs <- lapply(qs, jsonlite::parse_json, simplifyVector = TRUE)
              restore_inputs(!!!qs)
            }
          }
        },
        error = function(err) {
          # TODO show a good error here
          shiny::showNotification(

          )
        }
      )
    })

    # The use of moduleServer here is a trick to let us independently specify
    # bookmark excludes that cannot alter or be altered by other calls to
    # setBookmarkExclude().
    moduleServer(NULL, function(input, output, session) {
      observe({
        input_names <- names(input)
        setBookmarkExclude(c(
          grep("^shinytableau-setting-", input_names, value = TRUE),
          grep("^shinytableau-config-", input_names, value = TRUE),
          "shinytableau-settings",
          "shinytableau-schema"
        ))
      })
    })

    output[[ns("ui")]] <- renderUI({
      isolate({
        ui_func(session$request)
      })
    })

    output[[ns("footer_ui")]] <- renderUI({
      tagList(
        actionButton(ns("ok"), "OK", class = "btn-primary"),
        actionButton(ns("cancel"), "Cancel"),
        actionButton(ns("apply"), "Apply")
      )
    })

    iv <- shinyvalidate::InputValidator$new()
    args <- list(input = input, output = output, session = session, iv = iv)
    if (!"..." %in% names(formals(server_func))) {
      args <- args[names(args) %in% names(formals(server_func))]
    }
    result <- rlang::exec(server_func, !!!args)

    if (is.function(result)) {
      save_settings <- result
    } else if (is.list(result)) {
      save_settings <- result$save_settings
    }

    if (is.null(result)) {
      save_settings <- function() {}
    } else if (!is.function(result)) {
      # TODO: Throw appropriate error message, describing what was expected
      # and pointing to the appropriate help page
      stop("Unexpected result returned from config server function")
    }

    shiny::onBookmarked(function(url) {
      # print(url)
      update_tableau_settings_async("shinytableau_ui_state" = url, add. = TRUE)
    })

    apply_changes <- function() {
      if (iv$is_valid()) {
        promise_resolve(save_settings()) %...>% {
          session$doBookmark()
        } %...>% {
          TRUE
        }
      } else {
        iv$enable()
        promise_resolve(FALSE)
      }
    }

    observeEvent(input[[ns("ok")]], {
      apply_changes() %...>% {
        if (.) {
          tableau_close_dialog()
        }
      }
      # TODO: catch error
    })

    observeEvent(input[[ns("cancel")]], {
      tableau_close_dialog()
    })

    observeEvent(input[[ns("apply")]], {
      apply_changes()
      # TODO: Catch error (async)
    })
  }
}


# Config server must provide:
# - save_settings callback
