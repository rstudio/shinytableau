#' Create a skeleton YAML manifest file
#'
#' Tableau extensions require a manifest and the use of a YAML manifest file
#' in **shinytableau** allows for a separation of concerns when developing an
#' extension. With the `yaml_skeleton()` function, we can write a YAML manifest
#' file to disk; it contains all of the required fields for the extension with
#' example values. Later in the development lifecycle, the developer of a
#' **shinytableau** extension can use values relevant to the project.
#'
#' @param filename The name of the YAML file to create on disk. By default, this
#'   is `"manifest.yml"`.
#' @param path An optional path to which the YAML file should be saved (combined
#'   with `filename`).
#'
#' @examples
#' # Generate a YAML manifest file in the
#' # root directory of the project
#' # yaml_skeleton()
#'
#' # Generate the YAML file in a subdirectory
#' # and call the file 'manifest-temp.yml'
#' # yaml_skeleton(
#' #   filename = "manifest-temp.yml",
#' #   path = "app"
#' # )
#'
#' @export
yaml_skeleton <- function(filename = "manifest.yml",
                          path = NULL) {

  if (!is.null(path)) {
    filename <- file.path(path, filename)
  }

  filename <- fs::path_expand(filename)

  yaml::write_yaml(
    list(
      extension_id = "com.example.extensions.name",
      extension_version = "0.1.0",
      name = "My Extension",
      description = NULL,
      extended_description = NULL,
      author_name = "Your Name",
      author_email = NULL,
      author_organization = NULL,
      website = "https://example.com",
      source_location = NULL,
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

  # If the input to `path` doesn't specify a YAML
  # file, assume it is a path to a dir containing one
  if (grepl("\\.ya?ml$", path)) {

    path <- as.character(fs::path_abs(path))

  } else {

    if (!fs::dir_exists(path)) {
      stop(
        "The `path` provided must either:\n",
        " * Lead to a directory containing YAML file, or\n",
        " * Point directly to a YAML file",
        call. = FALSE
      )
    }

    yml_files <-
      list.files(path = path, pattern = "\\.ya?ml$", full.names = TRUE)

    if (length(yml_files) == 1) {
      path <- yml_files
    } else if (length(yml_files) > 1) {
      stop(
        "The `path` provided leads to multiple YAML files, either:\n",
        " * Specify a path to the appropriate YAML manifest file.\n",
        " * Remove extraneous YAML files, leaving only the YAML manifest file.",
        call. = FALSE
      )
    } else {
      stop(
        "The `path` provided doesn't lead to a YAML file, either:\n",
        " * Specify a path to the appropriate YAML manifest file.\n",
        " * Generate a YAML manifest file with `yaml_skeleton(\"", path, "\")`.",
        call. = FALSE
      )
    }
  }

  y <- yaml::read_yaml(file = path)

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
