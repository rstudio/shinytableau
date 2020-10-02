schema <- function(session) {
  session <- unwrap_session(session)

  shiny::isolate(session$input[["shinytableau-schema"]])
}

#' Get info about available worksheets in this Tableau dashboard
#'
#' For advanced use only; most shinytableau extensions should use the
#' [choose_data()] module to allow the user to specify a worksheet.
#'
#' @param session The Shiny `session` object. (You should probably just use the
#'   default.)
#' @param name A worksheet name, as returned by `tableau_worksheets()`.
#'
#' @return `tableau_worksheets()` returns a character vector whose elements are
#'   worksheet names. Note that only worksheets that are included on the same
#'   dashboard will be listed, and these are the only worksheets we can access.
#'
#'   `tableau_worksheet_info()` returns metadata for a specific worksheet. The
#'   return value is a named list that contains the following fields:
#'
#'   * **`name`** - The name of the worksheet.
#'
#'   * **`summary`** - The [data table schema object][DataTableSchema] for the
#'     worksheet's summary-level data table.
#'
#'   * **`dataSourceIds`** - Character vector of data source IDs used by this
#'     worksheet. See [tableau_datasource_info()].
#'
#'   * **`underlyingTables`** - Unnamed list, each element is a [data table
#'     schema object][DataTableSchema] of one of the worksheet's underlying
#'     data tables.
#'
#' @export
tableau_worksheets <- function(session = shiny::getDefaultReactiveDomain()) {
  names(schema(session)[["worksheets"]])
}

#' @rdname tableau_worksheets
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
#' If we want to access data from Tableau, the Tableau Extension API only allows
#' us to do so via one of the worksheets that are part of the same dashboard.
#'
#' Each worksheet makes three categories of data available to us:
#'
#' 1. **Summary data:** The data in its final form before visualization. If the
#'    visualization aggregates measures, then the summary data contains the data
#'    after aggregation has been performed. If the worksheet has an active
#'    selection, then by default, only the selected data is returned (set the
#'    `ignoreSelection` option to `TRUE` to retrieve all data).
#'
#' 2. **Underlying data:** The underlying data that is used in the visualization,
#'    before aggregation operations are performed but after tables are joined.
#'
#'    By default, only the columns that are used in the worksheet are included
#'    (set `includeAllColumns` to `TRUE` if you need them all). If the worksheet
#'    has an active selection, then by default, only the selected data is
#'    returned (set the `ignoreSelection` option to `TRUE` to retrieve all
#'    data).
#'
#' 3. **Data source:** You can also access the raw data from the data source(s)
#'    used by the worksheet. This data is unaffected by the worksheet settings.
#'    Tableau data sources are broken into one or more logical tables, like how
#'    a relational database has multiple tables.
#'
#' As an R user, you may find this analogy based on the examples from
#' [dplyr::mutate-joins] to be helpful in explaining the relationship between
#' data source, underlying, and summary data:
#'
#' ```
#' # Data source
#' logical1 <- band_members
#' logical2 <- band_instruments
#'
#' # Underlying is joined/selected, but not aggregated
#' underlying <- band_members %>%
#'   full_join(band_instruments, by = "name") %>%
#'   select(band, name)
#'
#' # Summary is underlying plus aggregation
#' summary <- underlying %>%
#'   group_by(band) %>%
#'   tally(name = "COUNT(name)")
#' ```
#'
#' The existence of these three levels of data granularity, plus the fact that
#' the underlying and data source levels need additional specification to narrow
#' down which of the multiple data tables at each level are desired, means that
#' providing clear instructions to `reactive_tableau_data` is surprisingly
#' complicated.
#'
#' Now that you have some context, see the description for the `spec` parameter,
#' above, for specific instructions on the different ways to specify data
#' tables, based on current user input, previously saved configuration, or
#' programmatically.
#'
#' ### Accessing a data table
#'
#' We turn our attention now to consuming data from `reactive_tableau_data()`.
#' Given the following code snippet, one that might appear in `config_server`:
#'
#' ```
#' data_spec <- choose_data("mydata")
#' data <- reactive_tableau_data(data_spec)
#' ```
#'
#' The `data` variable created here has two complications.
#'
#' First, it's reactive; like all reactive expressions, you must call `data` as
#' a function to get at its value. It must be reactive because Tableau data can
#' change (based on selection and filtering, if nothing else), and also, the
#' user's choices can change as well (in the example, the `data_spec` object is
#' also reactive).
#'
#' Second, and more seriously, reading Tableau data is asynchronous, so when you
#' invoke `data()` what you get back is not a data frame, but the [promise of a
#' data frame](https://rstudio.github.io/promises/articles/overview.html).
#' Working with promises has its own learning curve, so it's regrettable that
#' they play such a prominent role in reading Tableau data. If this is a new
#' topic for you, [start with this
#' talk](https://rstudio.com/resources/rstudioconf-2018/scaling-shiny-apps-with-async-programming/)
#' and then read through the various articles on the [promises
#' website](https://rstudio.github.io/promises/).
#'
#' The bottom line with promises is that you can use any of the normal functions
#' you usually use for manipulating, analyzing, and visualizing data frames, but
#' the manner in which you invoke those functions will be a bit different.
#' Instead of calling `print(data())`, for example, you'll need to first change
#' to the more pipe-oriented `data() %>% print()` and then replace the magrittr
#' pipe with the promise-pipe like `data() %...>% print()`. There's much more to
#' the story, though; for all but the simplest scenarios, you'll need to check
#' out the resources linked in the previous paragraph.
#'
#'
#' @param spec An argument that specifies what specific data should be
#'   accessed. This can be specified in a number of ways:
#'
#'   1. The name of a setting, that was set using a value returned from
#'   [choose_data()]. This is the most common scenario for `server`.
#'
#'   2. The object returned from [choose_data()] can be passed in directly. This
#'   is likely the approach you should take if you want to access data in
#'   `config_server` based on unsaved config changes (e.g. to give the user a
#'   live preview of what their `choose_data` choices would yield).
#'
#'   3. You can directly create a spec object using one of the helper functions
#'   [spec_summary()], [spec_underlying()], or [spec_datasource()]. For cases where
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
#'   * `truncation` - For underlying and datasource reads, Tableau will never,
#'     under any circumstances, return more than 10,000 rows of data. If `warn`
#'     (the default), when this condition occurs a warning will be displayed to
#'     the user and emitted as a warning in the R process, then the available
#'     data will be returned. If `ignore`, then no warning will be issued. If
#'     `error`, then an error will be raised.
#'
#' @param session The Shiny `session` object. (You should probably just use the
#'   default.)
#'
#' @examples
#' \dontrun{
#' data_spec_x <- choose_data("x", iv = iv)
#' data_x <- reactive_tableau_data(data_spec_x)
#' }
#'
#' @import promises
#' @export
reactive_tableau_data <- function(spec, options = list(),
  session = shiny::getDefaultReactiveDomain()) {

  force(spec)
  force(options)

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

  options <- merge_defaults(options, list(
    truncation = "warn"
  ))
  match.arg(options[["truncation"]], c("warn", "error", "ignore"))

  shiny::reactive({
    shiny::req(spec())

    if (!isTRUE(options[["ignoreSelection"]])) {
      # Take dependency
      session$input[["shinytableau-selection"]]
    }

    tableau_get_data_async(spec(), options) %...>% {
      if (isTRUE(.$isTotalRowCountLimited)) {
        if (options[["truncate"]] == "warn") {
          shiny::showNotification(
            htmltools::tagList(
              htmltools::strong("Warning:"),
              " Incomplete data; only the first ",
              nrow(.$data),
              " rows of data can be retrieved from Tableau!"
            ),
            type = "warning",
            session = session
          )
          warning("Tableau data was limited to first ", nrow(.$data), " rows")
        } else if (options[["truncate"]] == "error") {
          stop("The data requested contains too many rows (limit: ", nrow(.$data), ")")
        } else if (options[["truncate"]] == "ignore") {
          # Do nothing
        } else {
          warning("Unknown value for `truncate` option: ", options[["truncate"]])
        }
      }
      .$data
    }
  })
}

#' Create data spec objects programmatically
#'
#' A data spec object is a pointer to a specific data table in a Tableau
#' dashboard. It is analogous to a file path or a URL, except instead of a
#' simple string, it is a structured object consisting of multiple arguments.
#' The components of each data spec object will vary, depending on the type of
#' data being requested: summary, underlying, or data source. See the Details
#' section of [reactive_tableau_data()] for more information.
#'
#' @param worksheet The name (as character vector) or number (as integer) of the
#'   worksheet. If a number is given, it will immediately be resolved to a
#'   worksheet name.
#' @param underlyingTableId,dataSourceId,logicalTableId The id (as character
#'   vector) or number (as integer) of the specific underlying table/data
#'   source/logical table to read. If a number is given, it will immediately be
#'   resolved to an id.
#' @param session The Shiny `session` object. (You should probably just use the
#'   default.)
#'
#' @return A spec object, suitable for the `spec` argument to
#'   [reactive_tableau_data()] or persisting via
#'   [update_tableau_settings_async()].
#'
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

#' Construct a reactive expression that reads Tableau data schema
#'
#' Creates a reactive expression that returns schema data for the specified
#' Tableau data table, including the names and data types of columns. Basically,
#' this is a convenience wrapper that takes a `spec` object in any of its
#' various forms, invokes either [tableau_worksheet_info()] or
#' [tableau_datasource_info()] as appropriate, and extracts the specific
#' sub-object that matches `spec`.
#'
#' @param spec See [reactive_tableau_data()].
#' @param session The Shiny `session` object. (You should probably just use the
#'   default.)
#'
#' @return A named list, as described in the [DataTableSchema] topic.
#'
#' @export
reactive_tableau_schema <- function(spec, session = shiny::getDefaultReactiveDomain()) {

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
#'   * `dataType` - character - `"bool"`, `"date"`, `"date-time"`, `"float"`, `"int"`, `"spatial"`, or `"string"`.
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
