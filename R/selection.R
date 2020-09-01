#' Update a worksheet's selection using a `plotOutput` ggplot2 brush
#'
#' Shiny has its own built-in interactive plots feature (see
#' [this](https://shiny.rstudio.com/articles/plot-interaction.html) and
#' [this](https://shiny.rstudio.com/articles/selecting-rows-of-data.html) to get
#' started). The `tableau_select_marks_by_brush_async` function lets you take a
#' brush input from a [shiny::plotOutput()] and, if anything is selected, use it
#' to drive the selection of a Tableau worksheet within the same dashboard. Note
#' that because Tableau's selection model operates on marks, not rows in the
#' underlying data, **the x and y dimensions in the originating plot must be
#' represented in the summary data of the target worksheet.**
#'
#' @param worksheet Single-element character vector naming the worksheet whose
#'   selection we want to set. If your extension's configuration dialog uses
#'   [choose_data()] to allow the user to choose data, then use the
#'   `tableau_setting(YOUR_SETTING_ID)$worksheet` slot to access the worksheet
#'   name.
#' @param brush `input$YOUR_BRUSH_ID`, where `YOUR_BRUSH_ID` is the identifier
#'   passed as `plotOutput`'s `brush` argument (or passed to
#'   [shiny::brushOpts()], if you did it that way).
#'
#' @details
#' Currently this function only works with plots based on ggplot2, not base
#' graphics plots, because only ggplot2 plots supply the metadata that we need.
#' Future releases of Tableau may make it possible to provide this feature to
#' base plots as well.
#'
#' @return A [promises::promise] object. The promise object will not resolve to
#'   a useful value, but you can use it to handle errors.
#'
#' @export
tableau_select_marks_by_brush_async <- function(worksheet, brush) {

  # The Tableau extension API has a buggy worksheet.selectMarksByValueAsync
  # implementation. While the method takes an array of SelectionCriteria, that
  # only works if 1) every SelectionCriteria object in the array is the same
  # type (ranged or categorical); and 2) all of the SelectionCriteria objects'
  # fieldNames are unique. The first is confirmed by Tableau to be a bug, I
  # haven't reported the second at the time of this writing.
  #
  # In order to work around this, we perform a normal selection for the first
  # variable in the brush; and if there is a second variable, we perform the
  # removal of that variable's complement (to avoid bug #1), passing no more
  # than a single SelectionCriteria for each call (to avoid bug #2).

  criteria <- lapply(names(brush$mapping), function(var) {
    field <- brush$mapping[[var]]
    min <- brush[[paste0(var, "min")]]
    max <- brush[[paste0(var, "max")]]
    if (var %in% names(brush$domain$discrete_limits)) {
      type <- "categorical"
      value <- I(brush$domain$discrete_limits[[var]][round(min):round(max)])
      inverted_values <- I(list(brush$domain$discrete_limits[[var]][-round(min):-round(max)]))
    } else {
      type <- "ranged"
      value <- list(min = min, max = max)
      inverted_values <- list(
        # "-Inf" and "Inf" are strings because JSON can't represent them
        # natively. On the JS side, we search for these values and replace with
        # -Infinity and Infinity.
        list(min = "-Inf", max = min),
        list(min = max, max = "Inf")
      )
    }

    tibble::tibble(
      type = type,
      normal =
        list(           # list-column
          list(         # array
            list(       # SelectionCriteria object
              fieldName = field,
              value = value
            )
          )
        ),
      inverted =
        list(                                         # list-column
          lapply(inverted_values, function(inv_v) {   # array
            list(fieldName = field, value = inv_v)    # SelectionCriteria object
          })
        )
    )
  })
  criteria <- do.call(rbind, criteria)
  if (length(unique(criteria$type)) == 1) {
    begin_request("selectMarksByValue", worksheet, criteria$normal, "select-replace")
  } else {
    begin_request("selectMarksByValue2", worksheet, criteria$normal[[1]], criteria$inverted[-1])
  }

}

