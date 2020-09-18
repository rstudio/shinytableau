.onLoad <- function(libname, pkgname) {
  shiny::registerInputHandler("tableau_datatable", function(value, session, name) {
    as.data.frame(lapply(value, unlist), stringsAsFactors = FALSE)
  }, force = TRUE)

  shiny::registerInputHandler("tableau_schema", function(value, session, name) {
    if (is.null(value)) {
      return(value)
    }

    value$worksheets <- lapply(value$worksheets, function(worksheet) {
      worksheet$summary$columns <- long_to_wide(worksheet$summary$columns)
      worksheet$underlyingTables <- lapply(worksheet$underlyingTables, data_table_info)
      # Not sure why this is serializing as a list(character()), but it is
      worksheet$dataSourceIds <- unlist(worksheet$dataSourceIds)
      worksheet
    })

    value$dataSources <- lapply(value$dataSources, function(ds) {
      ds$fields <- long_to_wide(ds$fields)
      ds$logicalTables <- lapply(ds$logicalTables, data_table_info)
      if (!is.null(ds$extractUpdateTime)) {
        ds$extractUpdateTime <- strptime(ds$extractUpdateTime, "%m/%d/%Y %r")
      }
      ds
    })

    value
  }, force = TRUE)
}

long_to_wide <- function(lst) {
  tibble::as_tibble(do.call(rbind, lapply(lst, tibble::as_tibble)))
}

data_table_info <- function(table) {
  table$columns <- long_to_wide(table$columns)
  if (!is.null(table$marksInfo)) {
    table$marksInfo <- long_to_wide(table$marksInfo)
  }
  table
}
