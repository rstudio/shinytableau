#' @export
tableau_extension <- function(manifest, ui, server, config_ui = NULL,
  config_server = NULL, options = list()) {

  shiny::shinyApp(
    tableau_ui(manifest, ui, config_ui_template()),
    tableau_server(server, tableau_config_server(config_ui, config_server)),
    options = options, enableBookmarking = "url"
  )
}
