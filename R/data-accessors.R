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

#' Construct a reactive expression that reads Tableau data
#'
#' This function is used to read data from Tableau. Because of the many levels
#' of indirection involved in actually physically reading data from Tableau,
#' using this function is significantly more involved than, say, a simple
#' [read.csv()]. See the Details section for a more detailed introduction.
#'
#' There are two complicating factors when reading data from Tableau; the first
#' is how to tell shinytableau what specific data table you want to access, and
#' the second is actually accessing the data from R.
#'
#' ### Specifying a data table
#'
#' As of today, Tableau's Extension API requires you to access any data tables
#' via one of the worksheets on the same dashboard.
#'
#' @param spec An argument that specifies what specific data should be
#'   retrieved. This can be specified in a number of ways:
#'
#'   1. The name of a setting, that was set using a value returned from
#'   [choose_data()]. This is the most common scenario for `server`.
#'
#'   2. The object returned from [choose_data()] can be passed in directly. This
#'   is likely the approach you should take if you want to retrieve data in
#'   `config_server` based on unsaved config changes (e.g. to give the user a
#'   live preview of what their `choose_data` choices would yield).
#'
#'   3. You can directly create a spec object using one of the helper functions
#'   [spec_summary()], [spec_underlying()], or [spec_logical()]. For cases where
#'   the data is not selected based on [choose_data()] at all, but
#'   programmatically determined or hardcoded. (This should not be common.)
#'
#' @param options A named list of options:
#'
#'   * `ignoreAliases` - Do not use aliases specified in the data source in
#'   Tableau. Default is `FALSE`.
#'
#'   * `ignoreSelection` - If `FALSE` (the default), only return data for the
#'   currently selected marks. Does not apply for datasource tables, only
#'   summary and underlying.
#'
#'   * `includeAllColumns` - Return all the columns for the table. Default is
#'   `FALSE`. Does not apply for datasource and summary tables, only underlying.
#'
#'   * `maxRows` - The maximum number of rows to return. **Tableau will not,
#'   under any circumstances, return more than 10,000 rows for datasource and
#'   underlying tables.** This option is ignored for summary tables.
#'
#'   * `columnsToInclude` - Character vector of columns that should be included;
#'   leaving this option unspecified means all columns should be returned. Does
#'   not apply for summary and underlying, only datasource.
#'
#' @param session The Shiny `session` object. (You should probably just use the
#'   default.)
#'
#' @examples
#' data_spec_x <- choose_data("x", iv = iv)
#' data_x <- reactive_tableau_data(data_spec_x)
#'
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
spec_summary <- function(worksheet = 1L, session = shiny::getDefaultReactiveDomain()) {
  worksheet <- resolve_worksheet(worksheet, session = session)

  list(
    worksheet = worksheet,
    source = "summary"
  )
}

#' @rdname spec_summary
#' @export
spec_underlying <- function(worksheet = 1L, underlyingTableId = 1L, session = shiny::getDefaultReactiveDomain()) {
  worksheet <- resolve_worksheet(worksheet, session = session)

  wsi <- tableau_worksheet_info(worksheet, session = session)
  utables <- wsi[["underlyingTables"]]
  if (is.numeric(underlyingTableId) && underlyingTableId >= 1 && underlyingTableId <= length(utables)) {
    underlyingTableId <- utables[[underlyingTableId]][["id"]]
  } else if (is.character(underlyingTableId) && underlyingTableId %in% pluck(utables, "id")) {
    # Do nothing
  } else {
    stop("Underlying table not found")
  }

  list(
    worksheet = worksheet,
    source = "underlying",
    table = underlyingTableId
  )
}

#' @rdname spec_summary
#' @export
spec_datasource <- function(worksheet = 1L, dataSourceId = 1L, logicalTableId = 1L, session = shiny::getDefaultReactiveDomain()) {

  worksheet <- resolve_worksheet(worksheet, session = session)
  wsi <- tableau_worksheet_info(worksheet, session = session)

  dsIds <- wsi[["dataSourceIds"]]
  if (is.numeric(dataSourceId) && dataSourceId >= 1 && dataSourceId <= length(dsIds)) {
    dataSourceId <- dsIds[[dataSourceId]]
  } else if (is.character(dataSourceId) && dataSourceId %in% dsIds) {
    # Do nothing
  } else {
    stop("Specified data source not found")
  }

  dataSource <- tableau_datasource_info(dataSourceId, session = session)
  logicalTables <- dataSource[["logicalTables"]]
  if (is.numeric(logicalTableId) && logicalTableId >= 1 && logicalTableId <= length(logicalTables)) {
    logicalTableId <- logicalTables[[logicalTableId]][["id"]]
  } else if (is.character(logicalTableId) && logicalTableId %in% pluck(dataSource[["logicalTables"]], "id")) {
    # Do nothing
  } else {
    stop("Logical table not found")
  }

  list(
    worksheet = worksheet,
    source = "datasource",
    ds = dataSourceId,
    table = logicalTableId
  )
}

resolve_worksheet <- function(worksheet, session = shiny::getDefaultReactiveDomain()) {
  worksheet_names <- tableau_worksheets(session = session)

  if (is.numeric(worksheet) && worksheet >= 1L && worksheet <= length(worksheet_names)) {
    return(worksheet_names[[worksheet]])
  } else if (worksheet %in% worksheet_names) {
    return(worksheet)
  } else {
    stop("Requested worksheet not found")
  }
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

#' Get info about available data sources in this Tableau dashboard
#'
#' For advanced use only; most shinytableau extensions should use the
#' [choose_data()] module to allow the user to specify a data source.
#'
#' @param session The Shiny `session` object. (You should probably just use the
#'   default.)
#' @param id A data source ID, as returned by `tableau_datasources()` or
#'   [tableau_worksheet_info()]`$dataSourceIds`.
#'
#' @return `tableau_datasources()` returns a character vector whose elements are
#'   data source IDs.
#'
#'   `tableau_datasource_info()` returns the metadata and schema for a specific
#'   data source. Note that an extension instance can only access data sources
#'   that are actually used by worksheets in the same dashboard. The return
#'   value is a named list that contains the following fields:
#'   * **`id`** - Unique ID for this data source.
#'   * **`fields`** - data frame where each row is one of the fields in the data source, and these columns:
#'       * `aggregation` - character - The type of aggregation used for this field. Possible values listed [here](https://tableau.github.io/extensions-api/docs/enums/tableau.fieldaggregationtype.html), e.g. `"attr"`, `"avg"`, `"count"`, ...
#'       * `id` - character - The field id.
#'       * `name` - character - The caption for this field.
#'       * `description` - character - User description of the field, or `""` if there is none.
#'       * `role` - character - `"dimension"`, `"measure"`, or `"unknown"`.
#'       * `isCalculatedField` - logical - Whether the field is a table calculation.
#'       * `isCombinedField` - logical - Whether the field is a combination of multiple fields.
#'       * `isGenerated` - logical - Whether this field is generated by Tableau. Tableau generates a number of fields for a data source, such as Number of Records, or Measure Values. This property can be used to distinguish between those fields and fields that come from the underlying data connection, or were created by a user.
#'       * `isHidden` - logical - Whether this field is hidden.
#'   * **`isExtract`** - `TRUE` if this data source is an extract, `FALSE` otherwise.
#'   * **`name`** - The user friendly name of the data source as seen in the UI.
#'   * **`extractUpdateTime`** - A [POSIXlt] indicating the time of extract, or `NULL` if the data source is live.
#'   * **`logicalTables`** - An unnamed list; each element is a [data table schema][DataTableSchema].
#'
#' @export
tableau_datasources <- function(session = shiny::getDefaultReactiveDomain()) {
  names(schema(session)[["dataSources"]])
}

#' Data table schema object
#'
#' An object that describes the schema of a data table, like a worksheet's
#' summary data or underlying data, or a logical table from a data source.
#'
#' @seealso Data table schema objects are obtained via
#'   [tableau_worksheet_info()] and [tableau_datasource_info()].
#'
#' @field id Character vector indicating the ID of the underlying data table or
#'   logical table. (Not present for summary data.)
#' @field caption Character vector with a human-readable description of the
#'   underlying data table or logical table. (Not present for summary data.)
#' @field name Character vector with either `"Underlying Data Table"` or
#'   `"Summary Data Table"` (yes, literally those strings; not sure why this
#'   field is called `name` but it comes from the Tableau Extension API).
#' @field columns A data frame that describes the columns in this table. Each
#'   data frame row describes a column in the data table. The data frame
#'   contains these columns:
#'
#'   * `dataType` - character - `"float"`, `"integer"`, `"string"`, `"boolean"`, `"date"`, or `"datetime"`.
#'   * `fieldName` - character - The name of the column.
#'   * `index` - integer - The column number.
#'   * `isReferenced` - logical - If `TRUE`, then the column is referenced in the worksheet.
#'
#' @name DataTableSchema
#' @rdname DataTableSchema
NULL

#' @rdname tableau_datasources
#' @export
tableau_datasource_info <- function(id, session = shiny::getDefaultReactiveDomain()) {
  schema(session)[["dataSources"]][[id]]
}
