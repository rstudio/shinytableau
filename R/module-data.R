#' @export
choose_data_ui <- function(id, label, default = NULL, options = choose_data_options()) {
  htmltools::tags$div(
    id = id,
    class = "shinytableau-choose-data form-group shiny-input-container",
    !!!list_to_data_attr(options),

    htmltools::tags$label(class = "control-label", label),
    htmltools::tags$div(class = "shinytableau-choose-data-inner"),
  )
}

#' @export
choose_data_options <- function(
  source = c("any", "worksheet", "datasource"),
  aggregation = c("ask", "summary", "underlying"),
  ignore_aliases = c(FALSE, TRUE, "ask"),
  ignore_selection = c(FALSE, TRUE, "ask"),
  include_all_columns = c(FALSE, TRUE, "ask"),
  max_rows = c(0, "ask")
) {
  source <- match.arg(source, several.ok = TRUE)
  if ("any" %in% source) {
    source <- "any"
  }
  aggregation <- match.arg(aggregation)
  ignore_aliases <- match_fta(ignore_aliases)
  ignore_selection <- match_fta(ignore_selection)
  include_all_columns <- match_fta(include_all_columns)
  if (missing(max_rows)) {
    max_rows <- 0
  }
  if (!(is.numeric(max_rows) && length(max_rows) == 1) && !identical(max_rows, "ask")) {
    stop("Invalid value for `max_rows`; expected either a positive numeric value or \"ask\"")
  }

  if (source == "datasource" && aggregation == "summary") {
    stop("source='datasource' is not compatible with aggregation='summary'")
  }

  list(
    source = source,
    aggregation = aggregation,
    ignore_aliases = ignore_aliases,
    ignore_selection = ignore_selection,
    include_all_columns = include_all_columns,
    max_rows = max_rows
  )
}

# Transform a list to be suitable for inclusion as attributes on a tag.
# e.g. list(ignore_selection = TRUE) ==> list(`data-ignore-selection` = "1")
list_to_data_attr <- function(lst) {
  force(lst)
  names(lst) <- paste0("data-", gsub("_", "-", names(lst)))
  lapply(lst, function(x) {
    if (is.logical(x)) {
      as.character(as.numeric(x))
    } else {
      as.character(x)
    }
  })
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
