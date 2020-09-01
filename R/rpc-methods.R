#' @export
tableau_get_data_async <- function(spec, options = list()) {
  begin_request("getData", spec, options) %...>% (function(response) {
    response$data <- tibble::tibble(!!!response$data)
    response
  })
}

# We should implement this, but not until bugs in the Extension API are fixed;
# at the moment selectMarksByValueAsync is borderline unusable
# tableau_select_marks_by_value_async <- function(worksheet, selection_criteria, selection_mode) { }
