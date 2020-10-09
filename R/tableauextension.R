#' Create a Tableau Extension object
#'
#' `tableau_extension()` is to shinytableau extensions, what [shiny::shinyApp()]
#' is to Shiny apps. Both functions are used as the last expression of an app.R
#' file, and bring together the `ui` and `server` objects. However,
#' `tableau_extension()` has additional arguments for the Tableau extension
#' manifest (required) and configuration dialog UI and server (optional).
#'
#' @param manifest A Tableau manifest object, which provides a description of
#'   the extension for both human and machine use.
#'
#'   The easiest way to provide this information is by creating a manifest.yml
#'   file. Call the [yaml_skeleton()] function from the R prompt to create a
#'   sample manifest.yml in the same directory as your app.R file, then
#'   customize it for your extension. Then, in app.R, call `manifest <-
#'   [tableau_manifest_from_yaml()]` and pass the `manifest` object as this
#'   argument.
#'
#' @param ui **A function that takes a single `req` argument** and returns the
#'   UI definition of the extension. When the extension is added to a Tableau
#'   dashboard, this is the UI that will be displayed within the extension
#'   object.
#' @param server A function with three parameters (`input`, `output`, and
#'   `session`) that sets up the server-side reactive logic to go with `ui`.
#' @param config_ui Optional. **A function that takes a single `req` argument**
#'   and returns the UI definition to be used for the extension's configuration
#'   dialog. Unlike regular Shiny UI definitions, this should just be a
#'   [shiny::tagList()] or HTML object rather than an entire page like
#'   [shiny::fluidPage()] or [shiny::fillPage()].
#' @param config_server Optional. A function with four parameters (`input`,
#'   `output`, `session`, and `iv`) that sets up the server-side reactive logic
#'   to go with `config_ui`. The `iv` parameter is a
#'   [shinyvalidate::InputValidator] object that will enable when the config
#'   dialog's OK or Apply buttons are clicked. The `config_server` function must
#'   return a zero-argument function that, when run, calls
#'   [update_tableau_settings_async()] to persist the user's configuration
#'   preferences.
#' @param options See [ext_options()].
#'
#' @seealso See the [Getting Started
#'   guide](https://rstudio.github.io/shinytableau/articles/shinytableau.html)
#'   to learn more.
#'
#' @export
tableau_extension <- function(manifest, ui, server, config_ui = NULL,
  config_server = NULL, options = ext_options()) {
  force(manifest)
  force(ui)
  force(server)
  force(config_ui)
  force(config_server)
  force(options)

  # Just in case people pass `options = list(...)` instead of
  # `options = ext_options()`.
  options <- merge_defaults(options, ext_options())

  if (isTRUE(options[["use_theme"]])) {
    thematic::thematic_on(font = "Open Sans", bg = "white", fg = "black")
  }

  if (!is.null(config_ui) && !is.function(config_ui)) {
    stop("The `config_ui` argument, if provided, must be a function ",
      "that takes a single argument", call. = FALSE)
  }

  validate_server_function(server, "server")
  validate_server_function(config_server, "config_server", allowNULL = TRUE,
    optional_params = "iv")

  if (is.null(config_ui)) {
    options$prompt_for_config <- FALSE
  }

  shiny::shinyApp(
    tableau_ui(manifest,
      embed_ui_template(),
      config_ui_template(),
      options
    ),
    tableau_server(
      tableau_embed_server(manifest, ui, server, options),
      tableau_config_server(config_ui, config_server),
      options
    ),
    options = options,
    enableBookmarking = "url"
  )
}

#' Specify options for `tableau_extension`
#'
#' Use this function to modify the configuration options available for your
#' Tableau extension. Pass the resulting value as the `options` argument to
#' [tableau_extension()].
#'
#' @param config_width,config_height Numeric value specifying the initial width
#'   and height of the extension's configuration dialog (if any). In pixels.
#' @param prompt_for_config If the extension provides a configuration dialog
#'   (i.e. [tableau_extension()] is called with a `config_ui` argument),
#'   `prompt_for_config=TRUE` (the default) means that a newly added extension
#'   should not even attempt to render its `ui` and `server` in the dashboard;
#'   instead, a message instructing the Tableau user to use the configuration
#'   dialog is displayed instead.
#'
#'   Use `prompt_for_config=FALSE` if the extension is able to run even without
#'   initial configuration.
#' @param use_theme By default, shinytableau applies a customized version of
#'   Bootstrap 4 CSS to your extension's UI and config UI; the customizations
#'   are intended to complement Tableau's own UI conventions (though we cannot
#'   replicate them exactly due to licensing issues). Pass `FALSE` if you want
#'   to omit shinytableau's styles and just use your own.
#'
#' @param ... Options to pass through to [shiny::runApp] (e.g. `port`,
#'   `launch.browser`, `host`, `quiet`). For local development purposes, it's a
#'   good idea to assign `port` to a hardcoded number between 1025 and 49151
#'   that is unique for each extension.
#'
#' @return A list object, suitable for passing to `tableau_extension(options = ...)`.
#'
#' @export
ext_options <- function(config_width = 600, config_height = 400,
  prompt_for_config = TRUE, use_theme = TRUE, ...) {
  if (!is.numeric(config_width) || length(config_width) != 1) {
    stop("config_width must be a single number")
  }
  if (!is.numeric(config_height) || length(config_height) != 1) {
    stop("config_height must be a single number")
  }
  if (!is.logical(prompt_for_config) || length(prompt_for_config) != 1) {
    stop("prompt_for_config must be TRUE or FALSE")
  }
  if (!is.logical(use_theme) || length(use_theme) != 1) {
    stop("use_theme must be TRUE or FALSE")
  }

  rlang::list2(
    config_width = config_width,
    config_height = config_height,
    prompt_for_config = prompt_for_config,
    use_theme = use_theme,
    ...
  )
}

mode_from_querystring <- function(querystring, options) {
  mode <- shiny::parseQueryString(querystring)$mode
  if (!is.null(mode)) {
    mode
  } else {
    "info"
  }
}
