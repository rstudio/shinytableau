#' @export
choose_data_options <- function(
  aggregation = c("ask", "summary", "underlying", "datasource"),
  ignore_aliases = c(FALSE, TRUE, "ask"),
  ignore_selection = c(FALSE, TRUE, "ask"),
  include_all_columns = c(FALSE, TRUE, "ask"),
  max_rows = c(0, "ask")
) {
  aggregation <- match.arg(aggregation, several.ok = TRUE)
  ignore_aliases <- match_fta(ignore_aliases)
  ignore_selection <- match_fta(ignore_selection)
  include_all_columns <- match_fta(include_all_columns)
  if (missing(max_rows)) {
    max_rows <- 0
  }
  if (!(is.numeric(max_rows) && length(max_rows) == 1) && !identical(max_rows, "ask")) {
    stop("Invalid value for `max_rows`; expected either a positive numeric value or \"ask\"")
  }

  list(
    aggregation = aggregation,
    ignore_aliases = ignore_aliases,
    ignore_selection = ignore_selection,
    include_all_columns = include_all_columns,
    max_rows = max_rows
  )
}

#' @export
choose_data_ui <- function(id, label) {
  ns <- shiny::NS(id)
  htmltools::tagList(
    htmltools::tags$label(class = "control-label", label),
    htmltools::tags$div(class = "well", style = "width: 300px",
                    shiny::uiOutput(ns("worksheet_ui")),
      optional_chooser_ui(ns("agg")),
      optional_chooser_ui(ns("underlying")),
      optional_chooser_ui(ns("datasource")),
      optional_chooser_ui(ns("logical"))
    )
  )
}

#' @export
choose_data <- function(id, options = choose_data_options(), iv = NULL, session = shiny::getDefaultReactiveDomain()) {
  force(id)
  force(options)

  shiny::moduleServer(id, function(input, output, session) {
    worksheet_names <- tableau_worksheets(session)
    worksheets <- lapply(worksheet_names, tableau_worksheet_info, session = session)
    names(worksheets) <- worksheet_names

    datasource_ids <- tableau_datasources(session)
    datasources <- lapply(datasource_ids, tableau_datasource_info, session = session)
    names(datasources) <- datasource_ids

    ns <- session$ns

    if (!is.null(iv)) {
      iv$add_rule("worksheet", need, label = "Worksheet")
    }

    output$worksheet_ui <- shiny::renderUI({
      shiny::selectInput(ns("worksheet"), "Worksheet", choices = c(
        "Choose a worksheet" = "",
        stats::setNames(worksheet_names, worksheet_names)
      ))
    })

    worksheet <- shiny::reactive({
      worksheets[[shiny::req(input$worksheet)]]
    })

    agg_result <- optional_chooser("agg", NULL, shiny::reactive({
      shiny::req(input$worksheet)
      choices <- c(
        "Summary" = "summary",
        "Underlying data" = "underlying",
        "Data source" = "datasource"
      )
      agg_opts <- options$aggregation
      if ("ask" %in% agg_opts) {
        agg_opts <- c("summary", "underlying", "datasource")
      }
      choices <- choices[choices %in% agg_opts]
      choices
    }), chooser = shiny::radioButtons)

    underlying_result <- optional_chooser("underlying", NULL, shiny::reactive({
      shiny::req(agg_result() == "underlying")
      tables <- worksheet()[["underlyingTables"]]
      stats::setNames(pluck(tables, "id"), pluck(tables, "name"))
    }))

    underlying <- shiny::reactive({
      underlyingTables <- worksheet()[["underlyingTables"]]
      lookup(underlyingTables, "id", underlying_result())
    })

    datasource_result <- optional_chooser("datasource", NULL, shiny::reactive({
      shiny::req(agg_result() == "datasource")
      ws_datasources <- datasources[as.character(worksheet()[["dataSourceIds"]])]
      stats::setNames(pluck(ws_datasources, "id"), pluck(ws_datasources, "name"))
    }))

    logical_result <- optional_chooser("logical", NULL, r_choices = shiny::reactive({
      tables <- datasources[[datasource_result()]][["logicalTables"]]
      stats::setNames(pluck(tables, "id"), pluck(tables, "name"))
    }))

    logical_table <- shiny::reactive({
      tables <- datasources[[datasource_result()]][["logicalTables"]]
      lookup(tables, "name", logical_result())
    })

    selected <- shiny::reactive({
      switch(agg_result(),
        "summary" = worksheet()[["summary"]],
        "underlying" = underlying(),
        "datasource" = logical_table()
      )
    })

    spec <- shiny::reactive({
      c(
        list(worksheet = input$worksheet),
        list(source = agg_result()),
        if (agg_result() == "underlying") {
          list(table = underlying_result())
        },
        if (agg_result() == "datasource") {
          list(
            ds = datasource_result(),
            table = logical_result()
          )
        }
      )
    })

    return(spec)
  }, session)
}

#' Unpack settings from a `choose_data` module for `restore_input`
#'
#' The [choose_data()] module returns a spec object, suitable for storing as a
#' [tableau_setting()] and eventually passing to [reactive_tableau_data()]. This
#' function unpacks such a spec object and returns a list of input names/values
#' that can be passed to [restore_input()], using the rlang spread operator
#' ("`!!!`", see Examples below).
#'
#' @param id The same value as the `id` you're passing to the [choose_data()]
#'   module. (You'll need to call this once for each module you want to
#'   restore.)
#' @param spec Either `NULL`, or a data spec object, as generated by
#'   [choose_data()]. By default, will look for a Tableau setting named after
#'   the `id` value; pass `tableau_setting("some_other_value")` if you have
#'   saved the setting with a different name than the `id`.
#'
#' @examples
#' config_server <- function(input, output, session) {
#'   restore_inputs(
#'     !!!choose_data_unpack("data1")
#'   )
#'
#'   data1 <- choose_data("data1")
#'
#'   observe(input$ok, {
#'     update_tableau_settings(
#'       data1 = data1()
#'     )
#'   })
#' }
#'
#' @export
choose_data_unpack <- function(id, spec = shiny::isolate(tableau_setting(id))) {
  if (is.null(spec)) {
    return(NULL)
  }

  ns <- shiny::NS(id)
  results <- list()
  results[[ns("worksheet")]] <- spec[["worksheet"]]
  results[[ns(shiny::NS("agg", "choice"))]] <- spec[["source"]]
  if (identical(spec[["source"]], "underlying")) {
    results[[ns(shiny::NS("underlying", "choice"))]] <- spec[["table"]]
  } else if (identical(spec[["source"]], "datasource")) {
    results[[ns(shiny::NS("datasource", "choice"))]] <- spec[["ds"]]
    results[[ns(shiny::NS("logical", "choice"))]] <- spec[["table"]]
  }
  results
}

optional_chooser_ui <- function(id, ...) {
  ns <- shiny::NS(id)
  shiny::uiOutput(ns("ui"), ...)
}

optional_chooser <- function(id, label, r_choices = shiny::reactive(list()), chooser = shiny::selectInput) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    output$ui <- shiny::renderUI({
      choices <- r_choices()
      if (length(choices) <= 1) {
        return(NULL)
      } else {
        chooser(ns("choice"), label, choices)
      }
    })

    return(shiny::reactive({
      choices <- r_choices()
      if (length(choices) == 0) {
        return(NULL)
      } else if (length(choices) == 1) {
        return(unname(choices[[1]]))
      } else {
        return(shiny::req(input$choice))
      }
    }))
  })
}

pluck <- function(lst, prop, FUN.VALUE = character(1), USE.NAMES = TRUE) {
  vapply(lst, FUN.VALUE = FUN.VALUE, FUN = `[[`, j = prop, USE.NAMES = USE.NAMES)
}

lookup <- function(lst, prop, value) {
  for (el in lst) {
    if (el[[prop]] == value) {
      return(el)
    }
  }
  return(NULL)
}

# Require x to be one of FALSE, TRUE, "ask"
match_fta <- function(x) {
  arg_name <- as.character(substitute(x))
  if (identical(x, c(FALSE, TRUE, "ask"))) {
    return(FALSE)
  } else if (isTRUE(x %in% list(FALSE, TRUE, "ask"))) {
    return(x)
  } else {
    stop("Invalid value for `", arg_name, "`; expected FALSE, TRUE, or \"ask\"")
  }
}
