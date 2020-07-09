#' @export
tableau_get_data_async <- function(spec, options = list()) {
  begin_request("getData", spec, options) %...>% (function(response) {
    response$data <- tibble::tibble(!!!response$data)
    response
  })
}
