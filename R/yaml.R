#' Create and use a skeleton YAML manifest file
#'
#' Tableau extensions need to provide a
#' [manifest](https://tableau.github.io/extensions-api/docs/trex_manifest.html)
#' (`.trex`) file that Tableau users can load into their dashboards. This file
#' contains metadata such as the ID and name of the extension, the name and
#' email of the extension author, logo image, etc. With shinytableau, you as the
#' extension author do not create this file directly; instead, you provide a
#' simpler manifest.yml file.
#'
#' Call `yaml_skeleton()` from the R console to create a manifest.yml file.
#'
#' Call `tableau_manifest_from_yaml()` from your app.R to load it, and pass the
#' resulting object to [tableau_extension()].
#'
#' @param filename The (relative or absolute) file path where the YAML manifest
#'   file should be written. For an app.R based app, the recommended file path
#'   is `manifest.yml` in the same directory as app.R; for a package-based app,
#'   put the file in the package's `inst` directory, and call
#'   `tableau_manifest_from_yaml()` with [system.file()].
#' @param path The (relative or absolute) file or directory path from which to
#'   load an existing YAML manifest file. If the path is a directory, the
#'   filename `manifest.yml` will be added to the end of the path.
#' @return `yaml_skeleton` returns the filename, invisibly.
#'   `tableau_manifest_from_yaml` returns a manifest object that is suitable for
#'   passing to [tableau_extension()].
#'
#' @seealso See the [Getting Started
#'   guide](https://rstudio.github.io/shinytableau/articles/shinytableau.html)
#'   to learn more.
#'
#'   If the YAML file approach is inconvenient for some reason, you can also use
#'   [tableau_manifest()] to programmatically create a manifest.
#'
#' @examples
#' \dontrun{
#' # Generate a YAML manifest file in the
#' # root directory of the project
#' yaml_skeleton()
#'
#' # Generate the skeleton YAML manifest
#' # file (called `manifest.yml`) in the
#' # `app` subdirectory
#' yaml_skeleton(filename = "app/manifest.yml")
#' }
#' @export
yaml_skeleton <- function(filename = "manifest.yml") {

  filename <- fs::path_expand(filename)

  if (fs::file_exists(filename)) {
    stop(
      "The file `", fs::path_file(filename), "` already exists in the path.",
      call. = FALSE
    )
  }

  yml <-
    readLines(con = system.file(
      "manifest.yml",
      package = "shinytableau"
    ))

  # Don't care too much if this fails. Just trying to not literally hardcode the
  # extension id, in case people are too lazy to change it.
  try({
    project_name <- fs::path_file(fs::path_dir(fs::path_abs(filename)))
    if (nchar(project_name) != 0) {
      custom_id <- paste0("com.example.extensions.", project_name)
      yml <- sub("com.example.extensions.name", custom_id, yml, fixed = TRUE)
    }
  })

  writeLines(text = yml, con = filename)

  message("Manifest file successfully written to ", filename)

  if (interactive()) {
    utils::file.edit(filename)
  }

  invisible(filename)
}

#' @rdname yaml_skeleton
#' @export
tableau_manifest_from_yaml <- function(path = ".") {

  # Transform the path into an absolute path
  path <- fs::path_abs(path)

  if (!fs::file_exists(path)) {
    stop("The `path` provided does not exist", call. = FALSE)
  }

  # Is path pointing to a file
  if (fs::is_dir(path)) {

    # Combine the absolute path with the fixed
    # name of the YAML manifest file
    path <- fs::path_join(parts = c(path, "manifest.yml"))
    if (!fs::file_exists(path)) {
      stop("The `path` provided did not contain a manifest.yml file", call. = FALSE)
    }
  }

  # Read in the YAML manifest file as a list object
  y <- yaml::read_yaml(file = path)

  # Validate key names in the YAML file and provide a
  # warning for any invalid key names that are seen
  check_valid_yaml_key_names(yaml_list = y)

  # Resolve path of icon file
  path_icon_file <- resolve_file(y$icon, fs::path_dir(path), "icon")

  if (!is.null(y$extended_description)) {
    y$extended_description <-
      htmltools::HTML(commonmark::markdown_html(y$extended_description))
  }

  if (!is.null(y$screenshots)) {
    images <- vapply(y$screenshots, FUN.VALUE = character(1), FUN = function(sshot) {
      sshot <- resolve_file(sshot, start = fs::path_dir(path), "screenshots")
      as.character(htmltools::tags$p(htmltools::tags$img(
        src = base64enc::dataURI(file = sshot, mime = mime::guess_type(sshot)),
        style = htmltools::css(
          max_width = "100%",
          border = "1px solid #CCC",
          border_radius = "2px",
          box_sizing = "border-box",
          padding = "3px"
        )
      )))
    })
    y$extended_description <- htmltools::HTML(paste(collapse = "\n", c(y$extended_description, images)))
  }

  tableau_manifest(
    extension_id = y$extension_id,
    extension_version = y$extension_version,
    name = y$name,
    description = y$description,
    extended_description = y$extended_description,
    author_name = y$author_name,
    author_email = y$author_email,
    author_organization = y$author_organization,
    website = y$website,
    icon_file = path_icon_file,
    permissions = y$permissions,
    min_api_version = y$min_api_version
  )
}

resolve_file <- function(x, start, fieldname) {
  if (length(x) == 0) {
    return(NULL)
  }

  if (is.character(x)) {
    x <- list(file = x)
  }

  if (!is.list(x)) {
    stop("Invalid value provided for '", fieldname, "' metadata field")
  }

  if (!is.null(x$package)) {
    path <- system.file(x$file, package = x$package)
    if (nchar(path) == 0) {
      stop("Package ", x$package, " does not contain a file at ", x$file)
    }
  } else {
    path <- unclass(fs::path_abs(x$file, start = start))
    if (!file.exists(path)) {
      stop("File not found: ", path)
    }
  }

  path
}

check_valid_yaml_key_names <- function(yaml_list) {

  y_keys <- c(names(yaml_list), names(yaml_list$icon))

  if (!all(y_keys %in% manifest_keys_safe)) {

    unknown_keys <- y_keys[!(y_keys %in% manifest_keys_safe)]

    warning(
      "Invalid manifest keys are seen in the YAML manifest file:\n",
      " * They are: ", paste0("`", unknown_keys, "`", collapse = ", "), ".\n",
      " * Correct these key names in the `manifest.yml` file.",
      call. = FALSE
    )
  }
}

manifest_keys_safe <-
  c(
    "extension_id", "extension_version", "name", "description",
    "extended_description", "author_name", "author_email", "author_organization",
    "website", "source_location", "icon", "permissions",
    "min_api_version", "file", "package", "screenshots"
  )
