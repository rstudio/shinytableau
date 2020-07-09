schema <- function(session) {
  session <- unwrap_session(session)

  session$input[["shinytableau-schema"]]
}

#' @export
tableau_worksheets <- function(session = getDefaultReactiveDomain()) {
  names(schema(session)[["worksheets"]])
}

#' @export
tableau_worksheet_info <- function(name, session = getDefaultReactiveDomain()) {
  schema(session)[["worksheets"]][[name]]
}

#' @export
reactive_tableau_data <- function(spec, options = list(), session = getDefaultReactiveDomain()) {

  session <- unwrap_session(session)

  if (!is.function(spec)) {
    value <- spec
    spec <- function() value
  }

  reactive({
    req(spec())

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
tableau_datasources <- function(session = getDefaultReactiveDomain()) {
  names(schema(session)[["dataSources"]])
}

#' @export
tableau_datasource_info <- function(id, session = getDefaultReactiveDomain()) {
  schema(session)[["dataSources"]][[id]]
}
