#' Options for the `choose_data` module
#'
#' The [choose_data()] module has an `options` parameter. Use the
#' `choose_data_options` function to construct such option objects.
#'
#' @param aggregation A character vector indicating what kind of data is allowed
#'   to be selected from a worksheet:
#'   * `"summary"` (i.e. aggregated),
#'   * `"underlying"` (i.e. row-level), and/or
#'   * `"datasource"` (the logical
#'   table(s) from which the underlying data is derived).
#'
#'   A vector of length 1, 2, or 3 may be passed; if length 1, then the user
#'   will not be shown a choice.
#'
#'   The special value `"ask"` (the default) is equivalent to
#'   `c("summary", "underlying", "datasource")`.
#'
#' @seealso [choose_data()]
#'
#' @export
choose_data_options <- function(
  aggregation = c("ask", "summary", "underlying", "datasource")
) {
  aggregation <- match.arg(aggregation, several.ok = TRUE)

  list(
    aggregation = aggregation
  )
}

#' @param label Display label for the control, or `NULL` for no label.
#' @rdname choose_data
#' @export
choose_data_ui <- function(id, label = NULL) {
  ns <- shiny::NS(id)
  htmltools::tagList(
    if (!is.null(label)) {
      htmltools::tags$label(class = "control-label", label)
    },
    htmltools::tags$div(class = "well", style = "width: 300px",
                    shiny::uiOutput(ns("worksheet_ui")),
      optional_chooser_ui(ns("agg")),
      optional_chooser_ui(ns("underlying")),
      optional_chooser_ui(ns("datasource")),
      optional_chooser_ui(ns("logical"))
    )
  )
}

#' Shiny module to allow easy selecting of Tableau data
#'
#' A common task in configuration dialogs is telling the extension where it
#' should pull data from: from which worksheet, whether to use summary or
#' underlying data is desired, and for underlying data with multiple logical
#' tables, which logical table. This Shiny module provides a drop-in component
#' for prompting the user for these inputs in a consistent and usable way.
#'
#' @param id An identifier. Like a Shiny input or output id, corresponding UI
#'   (`choose_data_ui`) and server (`choose_data`) calls must use the same id,
#'   and the id must be unique within a scope (i.e. unique within the top-level
#'   Shiny server function, or unique within a given module server function).
#' @param options See [choose_data_options()].
#' @param iv A [shinyvalidate::InputValidator] object; almost certainly you'll
#'   want to use the one that shinytableau passes to you via the `iv` parameter
#'   of your `config_server` function (see the example below). If provided,
#'   `choose_data` will add validation rules to this object; specifically,
#'   validation will fail if the user does not select a worksheet.
#' @param session The Shiny `session` object. (You should probably just use the
#'   default.)
#'
#' @examples
#' # TODO
#'
#' @export
choose_data <- function(id, options = choose_data_options(), iv = NULL,
  session = shiny::getDefaultReactiveDomain()) {

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
      iv$add_rule("worksheet", shiny::need, label = "Worksheet")
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
