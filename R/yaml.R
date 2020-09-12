#' Create a skeleton YAML manifest file
#'
#' Tableau extensions require a manifest and the use of a YAML manifest file in
#' **shinytableau** allows for a separation of concerns when developing an
#' extension. With the `yaml_skeleton()` function, we can write a YAML manifest
#' file to disk; it contains all of the required fields for the extension with
#' example values. Later in the development lifecycle, the developer of a
#' **shinytableau** extension can use values relevant to the project.
#'
#' @param filename A filename for the YAML manifest file. Can be combined with a
#'   relative path. The default, and recommended, filename is `"manifest.yml"`.
#'
#' @examples
#' # Generate a YAML manifest file in the
#' # root directory of the project
#' # yaml_skeleton()
#'
#' # Generate the skeleton YAML manifest
#' # file (called `manifest.yml`) in the
#' # `app` subdirectory
#' # yaml_skeleton(filename = "app/manifest.yml")
#'
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
  path_icon_file <- y$icon$file
  if (!is.null(path_icon_file)) {
    if (!is.null(y$icon$package)) {
      path_icon_file <- system.file(path_icon_file, package = y$icon$package)
    } else if (!fs::is_absolute_path(path_icon_file)) {
      path_icon_file <-
        fs::path_abs(path_icon_file, start = fs::path_dir(path))
    }
  }

  if (!is.null(y$extended_description)) {
    y$extended_description <-
      htmltools::HTML(commonmark::markdown_html(y$extended_description))
  }

  # TODO: have image screenshot of app inlined in `extended_description`

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
    "min_api_version", "file", "package"
  )
