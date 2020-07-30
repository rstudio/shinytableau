#' @export
tableau_extension <- function(manifest, ui, server, config_ui = NULL,
  config_server = NULL, options = ext_options()) {

  shiny::shinyApp(
    tableau_ui(manifest, ui, config_ui_template(), options),
    tableau_server(server, tableau_config_server(config_ui, config_server)),
    options = options, enableBookmarking = "url"
  )
}

#' @param ... Options to pass through to [shiny::runApp] (e.g. `port`,
#'   `launch.browser`, `host`, `quiet`).
#' @export
ext_options <- function(config_width = 600, config_height = 400, ...) {
  if (!is.numeric(config_width) || length(config_width) != 1) {
    stop("config_width must be a single number")
  }
  if (!is.numeric(config_height) || length(config_height) != 1) {
    stop("config_height must be a single number")
  }

  rlang::list2(
    config_width = config_width,
    config_height = config_height,
    ...
  )
}
