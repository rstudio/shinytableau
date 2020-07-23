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
tableau_datasources <- function(session = shiny::getDefaultReactiveDomain()) {
  names(schema(session)[["dataSources"]])
}

#' @export
tableau_datasource_info <- function(id, session = shiny::getDefaultReactiveDomain()) {
  schema(session)[["dataSources"]][[id]]
}
