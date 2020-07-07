#' @export
tableau_extension <- function(manifest, ui, server, config_ui = NULL,
  config_server = NULL, options = list()) {

  shiny::shinyApp(
    tableau_ui(manifest, ui, config_ui),
    tableau_server(server, config_server),
    options = options
  )
}
