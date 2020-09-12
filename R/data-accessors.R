schema <- function(session) {
  session <- unwrap_session(session)

  shiny::isolate(session$input[["shinytableau-schema"]])
}

#' @export
tableau_worksheets <- function(session = shiny::getDefaultReactiveDomain()) {
  names(schema(session)[["worksheets"]])
}

#' @export
tableau_worksheet_info <- function(name, session = shiny::getDefaultReactiveDomain()) {
  schema(session)[["worksheets"]][[name]]
}

#' @import promises
#' @export
reactive_tableau_data <- function(spec, options = list(), session = shiny::getDefaultReactiveDomain()) {

  session <- unwrap_session(session)

  if (is.character(spec) && length(spec) == 1) {
    setting_name <- spec
    spec <- shiny::reactive({
      tableau_setting(setting_name, session = session)
    })
  }

  if (!is.function(spec)) {
    value <- spec
    spec <- function() value
  }

  shiny::reactive({
    shiny::req(spec())

    if (!isTRUE(options[["ignoreSelection"]])) {
      # Take dependency
      session$input[["shinytableau-selection"]]
    }

    tableau_get_data_async(spec(), options) %...>% {
      .$data
    }
  })
}

#' @export
reactive_tableau_schema <- function(spec, session = shiny::getDefaultReactiveDomain()) {

  session <- unwrap_session(session)

  if (!is.function(spec)) {
    value <- spec
    spec <- function() value
  }

  shiny::reactive({
    sp <- shiny::req(spec())

    worksheet_name <- sp[["worksheet"]]
    switch(sp[["source"]],
      summary = {
        return(tableau_worksheet_info(worksheet_name, session = session)[["summary"]])
      },
      underlying = {
        tables <- tableau_worksheet_info(worksheet_name, session = session)[["underlyingTables"]]
        shiny::req(tables)
        shiny::req(find_logical_table(tables, sp[["table"]]))
      },
      datasource = {
        tables <- tableau_datasource_info(sp[["ds"]], session = session)[["logicalTables"]]
        shiny::req(tables)
        shiny::req(find_logical_table(tables, sp[["table"]]))
      },
      stop("Unknown data_spec source: '", sp[["source"]], "'")
    )
  })
}

find_logical_table <- function(logical_tables, id) {
  for (table in logical_tables) {
    if (table[["id"]] == id) {
      return(table)
    }
  }
  return(NULL)
}

#' @export
tableau_datasources <- function(session = shiny::getDefaultReactiveDomain()) {
  names(schema(session)[["dataSources"]])
}

#' @export
tableau_datasource_info <- function(id, session = shiny::getDefaultReactiveDomain()) {
  schema(session)[["dataSources"]][[id]]
}
