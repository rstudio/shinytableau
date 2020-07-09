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
  ns <- NS(id)
  tagList(
    tags$label(class = "control-label", label),
    tags$div(class = "well", style = "width: 300px",
      uiOutput(ns("worksheet_ui")),
      optional_chooser_ui(ns("agg")),
      optional_chooser_ui(ns("underlying")),
      optional_chooser_ui(ns("datasource")),
      optional_chooser_ui(ns("logical"))
    )
  )
}

#' @export
choose_data <- function(id, options = choose_data_options(), session = getDefaultReactiveDomain()) {
  force(id)
  force(options)

  moduleServer(id, function(input, output, session) {
    worksheet_names <- tableau_worksheets(session)
    worksheets <- lapply(worksheet_names, tableau_worksheet_info, session = session)
    names(worksheets) <- worksheet_names

    datasource_ids <- tableau_datasources(session)
    datasources <- lapply(datasource_ids, tableau_datasource_info, session = session)
    names(datasources) <- datasource_ids

    ns <- session$ns

    output$worksheet_ui <- renderUI({
      selectInput(ns("worksheet"), "Worksheet", choices = c(
        "Choose a worksheet" = "",
        setNames(worksheet_names, worksheet_names)
      ))
    })

    worksheet <- reactive({
      worksheets[[req(input$worksheet)]]
    })

    agg_result <- optional_chooser("agg", NULL, reactive({
      req(input$worksheet)
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
    }), chooser = radioButtons)

    underlying_result <- optional_chooser("underlying", NULL, reactive({
      req(agg_result() == "underlying")
      tables <- worksheet()[["underlyingTables"]]
      setNames(pluck(tables, "id"), pluck(tables, "name"))
    }))

    underlying <- reactive({
      underlyingTables <- worksheet()[["underlyingTables"]]
      lookup(underlyingTables, "id", underlying_result())
    })

    datasource_result <- optional_chooser("datasource", NULL, reactive({
      req(agg_result() == "datasource")
      ws_datasources <- datasources[as.character(worksheet()[["dataSourceIds"]])]
      setNames(pluck(ws_datasources, "id"), pluck(ws_datasources, "name"))
    }))

    logical_result <- optional_chooser("logical", NULL, r_choices = reactive({
      tables <- datasources[[datasource_result()]][["logicalTables"]]
      setNames(pluck(tables, "id"), pluck(tables, "name"))
    }))

    logical_table <- reactive({
      tables <- datasources[[datasource_result()]][["logicalTables"]]
      lookup(tables, "name", logical_result())
    })

    selected <- reactive({
      switch(agg_result(),
        "summary" = worksheet()[["summary"]],
        "underlying" = underlying(),
        "datasource" = logical_table()
      )
    })

    spec <- reactive({
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
  ns <- NS(id)
  uiOutput(ns("ui"), ...)
}

optional_chooser <- function(id, label, r_choices = reactive(list()), chooser = selectInput) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    output$ui <- renderUI({
      choices <- r_choices()
      if (length(choices) <= 1) {
        return(NULL)
      } else {
        chooser(ns("choice"), label, choices)
      }
    })

    return(reactive({
      choices <- r_choices()
      if (length(choices) == 0) {
        return(NULL)
      } else if (length(choices) == 1) {
        return(unname(choices[[1]]))
      } else {
        return(req(input$choice))
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
