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

  # TODO: Don't break existing theme variables
  bootstraplib::bs_theme_new()
  bootstraplib::bs_theme_add(
    defaults = sass::sass_file(system.file("theme/defaults.scss", package = "shinytableau")),
    declarations = sass::sass_file(system.file("theme/declarations.scss", package = "shinytableau")),
    rules = sass::sass_file(system.file("theme/rules.scss", package = "shinytableau"))
  )

  list(
    tableau_extensions_api_lib(),
    htmltools::htmlDependency(
      "shinytableau",
      version = utils::packageVersion("shinytableau"),
      src = "assets",
      package = "shinytableau",
      script = "js/shinytableau.js",
      all_files = FALSE
    ),
    bootstraplib::bootstrap()
  )
}
