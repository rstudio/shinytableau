schema <- function(session) {
  session$input[["shinytableau-schema"]]
}

#' @export
tableau_worksheets <- function(session = getDefaultReactiveDomain()) {
  names(schema(session)[["worksheets"]])
}

#' @export
tableau_worksheet <- function(name, session = getDefaultReactiveDomain()) {
  schema(session)[["worksheets"]][[name]]
}

#' @export
tableau_datasources <- function(session = getDefaultReactiveDomain()) {
  names(schema(session)[["dataSources"]])
}

#' @export
tableau_datasource <- function(id, session = getDefaultReactiveDomain()) {
  schema(session)[["dataSources"]][[id]]
}
