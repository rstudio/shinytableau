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
        path = "default_icon.png",
        package = "shinytableau"
      ),
      permissions = "full data",
      configure = NULL,
      min_api_version = "1.4"
    ),
    file = filename
  )
}
