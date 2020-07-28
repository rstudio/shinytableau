#' @export
tableau_extension <- function(manifest, ui, server, config_ui = NULL,
  config_server = NULL, options = list()) {

  # Here `thematic::shiny()` is used to specify a font replacement;
  # The 'Open Sans' font will be obtained from Google Fonts (i.e.,
  # downloaded and installed on the user's system) if not already
  # available; after exiting from the `tableau_extension()` Shiny app,
  # thematic will clean up after itself (font option is used globally)
  thematic::thematic_shiny(font = "Open Sans")

  shiny::shinyApp(
    tableau_ui(manifest, ui, config_ui),
    tableau_server(server, config_server),
    options = options
  )
}
