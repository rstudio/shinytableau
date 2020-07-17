#' Create a skeleton YAML manifest file
#'
#' Tableau extensions require a manifest and the use of a YAML manifest file
#' in **shinytableau** allows for a separation of concerns when developing an
#' extension. With the `yaml_skeleton()` function, we can write a YAML manifest
#' file to disk; it contains all of the required fields for the extension with
#' example values. Later in the development lifecycle, the developer of a
#' **shinytableau** extension can use values relevant to the project.
#'
#' @param path A path in which the `"manifest.yml"` file will be created.
#'
#' @examples
#' # Generate a YAML manifest file in the
#' # root directory of the project
#' # yaml_skeleton()
#'
#' # Generate the skeleton YAML manifest
#' # file (called `manifest.yml`) in the
#' # `app` subdirectory
#' # yaml_skeleton(path = "app")
#'
#' @export
yaml_skeleton <- function(path = ".") {

  filename <- "manifest.yml"

  if (!is.null(path)) {
    filename <- file.path(path, filename)
  }

  filename <- fs::path_expand(filename)

  yaml::write_yaml(
    list(
      extension_id = "com.example.extensions.name",
      extension_version = "0.1.0",
      name = "My Extension",
      description = "Description of the Extension",
      extended_description = "A much longer Description of the Extension",
      author_name = "Your Name",
      author_email = "author@example.com",
      author_organization = "Example Organization",
      website = "https://example.com",
      source_location = "https://example.com/source/",
      icon = list(
        file = "default_icon.png",
        package = "shinytableau"
      ),
      permissions = "full data",
      configure = TRUE,
      min_api_version = "1.4"
    ),
    file = filename
  )
}



#' @export
tableau_manifest_from_yaml <- function(path = ".") {

  # Transform the path into an absolute path
  path <- fs::path_abs(path)

  # Is path pointing to a file
  if (fs::is_dir(path)) {

    # Combine the absolute path with the fixed
    # name of the YAML manifest file
    path <- fs::path_join(parts = c(path, "manifest.yml"))
  }

  # If the YAML manifest file doesn't exist, throw an error
  if (!fs::file_exists(path) ||
      (fs::file_exists(path) && fs::path_file(path) != "manifest.yml")) {
    stop(
      "The `path` provided must either:\n",
      " * Represent a directory containing `manifest.yml`, or\n",
      " * Point directly to a `manifest.yml` file",
      call. = FALSE
    )
  }

  # Read in the YAML manifest file as a list object
  y <- yaml::read_yaml(file = path)

  # Validate key names in the YAML file and provide a
  # warning for any invalid key names that are seen
  check_valid_yaml_key_names(yaml_list = y)

  tableau_manifest(
    extension_id = y$extension_id,
    extension_version = y$extension_version,
    name = y$name,
    description = y$description,
    extended_description = y$extende_description,
    author_name = y$author_name,
    author_email = y$author_email,
    author_organization = y$author_organization,
    website = y$website,
    source_location = y$source_location,
    icon_file = y$icon$file,
    icon_package = y$icon$package,
    permissions = y$permissions,
    configure = y$configure,
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
    "website", "source_location", "icon", "permissions", "configure",
    "min_api_version", "file", "package"
  )
