#' @export
tableau_extension <- function(manifest, ui, server, config_ui = NULL,
  config_server = NULL, options = ext_options()) {
  force(manifest)
  force(ui)
  force(server)
  force(config_ui)
  force(config_server)
  force(options)

  if (!is.null(config_ui) && !is.function(config_ui)) {
    stop("The `config_ui` argument, if provided, must be a function ",
      "that takes a single argument", call. = FALSE)
  }

  shiny::shinyApp(
    tableau_ui(manifest,
      embed_ui_template(),
      config_ui_template(),
      options
    ),
    tableau_server(
      tableau_embed_server(manifest, ui, server, options),
      tableau_config_server(config_ui, config_server)
    ),
    options = options,
    enableBookmarking = "url"
  )
}

#' @param ... Options to pass through to [shiny::runApp] (e.g. `port`,
#'   `launch.browser`, `host`, `quiet`).
#' @export
ext_options <- function(config_width = 600, config_height = 400,
  prompt_for_config = TRUE, ...) {
  if (!is.numeric(config_width) || length(config_width) != 1) {
    stop("config_width must be a single number")
  }
  if (!is.numeric(config_height) || length(config_height) != 1) {
    stop("config_height must be a single number")
  }
  if (!is.logical(prompt_for_config) || length(prompt_for_config) != 1) {
    stop("prompt_for_config must be TRUE or FALSE")
  }

  rlang::list2(
    config_width = config_width,
    config_height = config_height,
    prompt_for_config = prompt_for_config,
    ...
  )
}
