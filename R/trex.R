#' Generate a Tableau Extension Manifest
#'
#' The `tableau_manifest()` function generates Tableau Extension Manifest XML
#' which constitutes the extension manifest file (with the standard extension
#' `.trex`). This XML text contains metadata for the extension and is used for
#' registration.
#'
#' @param extension_id The ID value for the Tableau extension which follows the
#'   reverse domain name pattern. By default, this is set to a placeholder value
#'   of `"com.example.extensions.name"`
#' @param extension_version The version number for the extension. The default
#'   value for this is `"0.1.0"`.
#' @param name The name of the extension. This name will appear as given under
#'   *Extensions* on a *Tableau* dashboard sheet.
#' @param description,extended_description The description and extended
#'   description for the extension. Whereas `description` expects a relatively
#'   short amount of text, the `extended_description` parameter serves as a
#'   long-form description of the extension. HTML text can be used for the
#'   latter.
#' @param author_name,author_email,author_organization,website Details about the
#'   extension author and project website.
#' @param source_location The source location, which is the URL of the server
#'   that hosts the web page that in turns interacts with Tableau.
#' @param icon_file The path to the icon file to be used for the extension. The
#'   image should be no larger than 70x70px.
#' @param permissions A setting that determines the level of permissions. The
#'   default `"full_data"` is the default and currently the only available
#'   option for Tableau extensions. This declaration is required since the
#'   extension can access the underlying data or information about the data
#'   sources.
#' @param configure If `TRUE` (the default) then the context menu for the
#'   extension will be configured.
#' @param min_api_version This specifies the minimum API version required for
#'   running the extension. The default for this is `"1.4"`.
#'
#' @examples
#' # Create a Tableau Manifest via the
#' # `tableau_manifest()` function
#' tableau_manifest(
#'   extension_id = "com.example.ggvoronoi",
#'   extension_version = "1.1.3",
#'   name = "Voronoi Plot",
#'   description = "Insert a Voronoi plot using ggvoronoi",
#'   author_name = "Jane Doe",
#'   author_email = "jane_doe@example.com",
#'   website = "https://example.com/tableau/extensions/ggvoronoi"
#' )
#'
#' @export
tableau_manifest <- function(
  extension_id = "com.example.extensions.name",
  extension_version = "0.1.0",
  name = "My extension",
  description = NULL,
  extended_description = description,
  author_name = "Your Name",
  author_email = "author@example.com",
  author_organization = "Example Organization",
  website = "https://example.com",
  source_location = NULL,
  icon_file = "default_icon.png",
  permissions = c("full data"),
  configure = TRUE,
  min_api_version = "1.4"
) {

  # if (missing(extension_id)) { stop("`extension_id` is a required argument") }
  # if (missing(extension_version)) { stop("`extension_version` is a required argument") }
  # if (missing(name)) { stop("`name` is a required argument") }
  # if (missing(author_name)) { stop("`author_name` is a required argument") }
  # if (missing(website)) { stop("`website` is a required argument") }

  permissions <- match.arg(permissions)

  if (!file.exists(icon_file)) {
    stop("The icon file was not found.", call. = FALSE)
  }

  structure(
    list(
      extension_id = extension_id,
      extension_version = extension_version,
      name = name,
      description = description,
      extended_description = extended_description,
      author_name = author_name,
      author_email = author_email,
      author_organization = author_organization,
      website = website,
      source_location = source_location,
      icon = base64enc::base64encode(icon_file),
      permissions = permissions,
      configure = configure,
      min_api_version = min_api_version
    ),
    class = "tableau_manifest"
  )
}

#' @keywords internal
#' @export
print.tableau_manifest <- function(x, ...) {
  cat(render_manifest(x))
}

render_manifest <- function(manifest) {
  with(manifest, {
    x <- tag_helper
    result <- x("manifest",
      `manifest-version` = "0.1",
      xmlns="http://www.tableau.com/xml/extension_manifest",

      x("dashboard-extension",
        id = extension_id,
        `extension-version` = extension_version,

        x("default-locale", "en_US"),
        x("name", name),
        if (!is.null(description)) x("description", description),
        x("author",
          name = author_name,
          email = author_email,
          organization = author_organization,
          website = website
        ),
        x("min-api-version", min_api_version),
        x("source-location",
          x("url",
            source_location
          )
        ),
        x("icon", icon),
        x("permissions",
          lapply(permissions, x, tagname = "permission")
        ),
        x("context-menu",
          if (configure) {
            x("configure-context-menu-item")
          }
        )
      )
    )

    paste0('<?xml version="1.0" encoding="utf-8"?>\n\n',
      enc2utf8(as.character(result))
    )
  })
}

tag_helper <- function(tagname, ...) {
  htmltools::tag(tagname, list(...))
}
