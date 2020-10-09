tableau_extensions_api_lib <- function() {
  htmltools::htmlDependency(
    "tableau-extensions",
    version = "1.4.0",
    src = "lib/tableau-extensions",
    package = "shinytableau",
    script = "tableau.extensions.1.4.0.min.js",
    all_files = FALSE
  )
}

#' Bootstrap 4 theme for shinytableau
#'
#' Use the return value for `shinytableau_theme()` as the `theme` argument for
#' [shiny::fillPage()], [shiny::fluidPage()], etc. to add some CSS rules that
#' make some Shiny controls look more like Tableau. This is only necessary for
#' `ui` objects, not `config_ui`, as the latter includes this automatically.
#'
#' @export
shinytableau_theme <- function() {
  theme <- bootstraplib::bs_theme("4+3")
  theme <- bootstraplib::bs_add_layers(theme,
    sass::sass_layer(
      defaults = sass::sass_file(system.file("theme/defaults.scss", package = "shinytableau")),
      declarations = sass::sass_file(system.file("theme/declarations.scss", package = "shinytableau")),
      rules = sass::sass_file(system.file("theme/rules.scss", package = "shinytableau"))
    )
  )
  theme
}

shinytableau_lib <- function() {

  # debugPath <- file.path(here::here(), "inst/assets")
  # if (dir.exists(debugPath) && dir.exists(file.path(here::here(), "inst/lib/tableau-extensions"))) {
  #   message("Using debug copy of shinytableau.js")
  #   return(list(
  #     tableau_extensions_api_lib(),
  #     htmltools::htmlDependency(
  #       "shinytableau",
  #       version = utils::packageVersion("shinytableau"),
  #       src = debugPath,
  #       script = "js/shinytableau.js",
  #       stylesheet = "css/styles.css",
  #       all_files = FALSE
  #     )
  #   ))
  # }

  list(
    tableau_extensions_api_lib(),
    htmltools::htmlDependency(
      "shinytableau",
      version = utils::packageVersion("shinytableau"),
      src = "assets",
      package = "shinytableau",
      script = "js/shinytableau.js",
      all_files = FALSE
    )
  )
}
