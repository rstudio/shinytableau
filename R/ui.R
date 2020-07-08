#' @export
tableau_ui <- function(manifest, ui, config_ui) {
  force(manifest)
  force(ui)
  force(config_ui)

  trex_initialized <- FALSE

  function(req) {
    if (!trex_initialized) {
      initialize_trex(manifest, !is.null(config_ui), req)
    }

    qs <- parseQueryString(req[["QUERY_STRING"]])
    mode <- qs[["mode"]]
    if (identical(mode, "embed")) {
      display_with_deps(ui, req)
    } else if (identical(mode, "configure")) {
      if (!is.null(config_ui)) {
        display_with_deps(config_ui, req, TRUE)
      } else {
        "This extension has no settings to configure"
      }
    } else {
      welcome_ui(manifest)
    }
  }
}

display_with_deps <- function(x, req, react = FALSE) {
  if (is.function(x)) {
    return(htmltools::tagList(
      if (react) reactR::html_dependency_react(),
      shinytableau::shinytableau_lib(),
      x(req)
    ))
  } else {
    return(htmltools::tagList(
      if (react) reactR::html_dependency_react(),
      shinytableau::shinytableau_lib(),
      x
    ))
  }
}

initialize_trex <- function(manifest, has_config, req) {
  if (is.null(manifest[["source_location"]])) {
    host <- req[["HTTP_HOST"]]
    if (is.null(host)) {
      host <- paste0(req[["SERVER_NAME"]], ":", req[["SERVER_PORT"]])
    }

    # Tableau hates 127.0.0.1 (and presumably [::1])
    host <- sub("^(\\[::1\\]|127\\.0\\.0\\.1)(:|$)", "localhost\\2", host)

    manifest$source_location <- paste0(
      req[["rook.url_scheme"]],
      "://",
      host,
      req[["SCRIPT_NAME"]],
      req[["PATH_INFO"]],
      "?mode=embed"
    )
  }

  if (is.null(manifest[["configure"]])) {
    manifest$configure <- isTRUE(has_config)
  }

  str <- render_manifest(manifest)
  trexdir <- tempfile(pattern = "trex")
  dir.create(trexdir)
  addResourcePath("shinytableau-trex", trexdir)
  writeBin(charToRaw(str), file.path(trexdir, "generated.trex"))
}

welcome_ui <- function(manifest) {
  trexfilename <- paste0(manifest[["name"]], ".trex")

  htmltools::tagList(
    includeCSS(system.file("welcome/welcome.css", package = "shinytableau")),
    htmlTemplate(system.file("welcome/welcome.html", package = "shinytableau"),
      manifest = manifest,
      trexfilename = trexfilename,
      author = author_html(manifest),
      document_ = FALSE)
  )
}

author_html <- function(manifest) {
  name <- manifest[["author_name"]]
  email <- manifest[["author_email"]]
  org <- manifest[["author_organization"]]

  author <- name
  if (!is.null(email)) {
    author <- htmltools::tags$a(
      href = paste0("mailto:", email),
      title = email,
      name
    )
  }
  if (!is.null(org)) {
    author <- tagList(author,
      paste0(" (", org, ")")
    )
  }
  author
}
