#' @examples
#' tableau_manifest(
#'   extension_id = "com.example.ggvoronoi",
#'   extension_version = "1.1.3",
#'   name = "Voronoi Plot",
#'   description = "Insert a Voronoi plot using ggvoronoi",
#'   author_name = "Jane Doe",
#'   author_email = "jane_doe@example.com",
#'   website = "https://example.com/tableau/extensions/ggvoronoi"
#' )
#' @export
tableau_manifest <- function(
  extension_id = "com.example.extensions.name",
  extension_version = "0.1.0",
  name = "My extension",
  description = NULL,
  extended_description = description,
  author_name = "Your Name",
  author_email = NULL,
  author_organization = NULL,
  website = "https://example.com",
  source_location = NULL,
  icon = system.file("default_icon.png", package = "shinytableau"),
  permissions = c("full data"),
  configure = NULL,
  min_api_version = "1.4"
) {
  if (missing(extension_id)) { stop("`extension_id` is a required argument") }
  if (missing(extension_version)) { stop("`extension_version` is a required argument") }
  if (missing(name)) { stop("`name` is a required argument") }
  if (missing(author_name)) { stop("`author_name` is a required argument") }
  if (missing(website)) { stop("`website` is a required argument") }

  permissions <- match.arg(permissions)

  if (!file.exists(icon)) {
    stop("The icon file was not found")
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
      icon = base64enc::base64encode(icon),
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
