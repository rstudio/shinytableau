trex_handler <- function(req, manifest, has_config) {
  if (is.null(manifest[["source_location"]])) {
    manifest$source_location <- infer_embed_url(req)
  }

  if (is.null(manifest[["configure"]])) {
    manifest$configure <- isTRUE(has_config)
  }

  filename <- paste0(manifest[["name"]], ".trex")

  str <- render_manifest(manifest)
  shiny::httpResponse(200L,
    content_type = "binary/octet-stream",
    content = charToRaw(enc2utf8(paste0(str, collapse = "\n"))),
    headers = list(
      "Content-Disposition" = content_disposition("attachment", filename)
    )
  )
}

infer_embed_url <- function(req) {

  url <-
    # Connect
    req[["HTTP_X_RSC_REQUEST"]] %||%
    req[["HTTP_RSTUDIO_CONNECT_APP_BASE_URL"]] %||%
    # ShinyApps.io
    req[["HTTP_X_REDX_FRONTEND_NAME"]]

  if (is.null(url)) {
    forwarded_host <- req[["HTTP_X_FORWARDED_HOST"]]
    forwarded_port <- req[["HTTP_X_FORWARDED_PORT"]]

    host <- if (!is.null(forwarded_host) && !is.null(forwarded_port)) {
      paste0(forwarded_host, ":", forwarded_port)
    } else {
      req[["HTTP_HOST"]] %||% paste0(req[["SERVER_NAME"]], ":", req[["SERVER_PORT"]])
    }

    # Tableau hates 127.0.0.1 (and presumably [::1])
    host <- sub("^(\\[::1\\]|127\\.0\\.0\\.1)(:|$)", "localhost\\2", host)

    proto <- req[["HTTP_X_FORWARDED_PROTO"]] %||% req[["rook.url_scheme"]]

    if (tolower(proto) == "http") {
      host <- sub(":80$", "", host)
    } else if (tolower(proto) == "https") {
      host <- sub(":443$", "", host)
    }

    url <- paste0(
      proto,
      "://",
      host,
      req[["SCRIPT_NAME"]],
      req[["PATH_INFO"]]
    )
  }

  # Strip existing querystring, if any
  url <- sub("\\?.*", "", url)
  paste0(url, "?mode=embed")
}

content_disposition <- function(disposition, filename = NULL) {
  if (is.null(filename)) {
    return(disposition)
  } else {
    paste0(disposition, "; filename*=", escape_encode(filename))
  }
}

escape_encode <- function(str) {
  stopifnot(is.character(str))
  stopifnot(length(str) == 1)

  str <- enc2utf8(str)

  chars <- strsplit(str, "", fixed = TRUE)[[1]]
  any_encoded <- FALSE
  encoded <- vapply(chars, function(char) {
    bytes <- charToRaw(char)
    needs_encoding <- chars %in% c('"', " ", "\r", "\n", "\\", "%") || length(bytes) > 1
    if (needs_encoding) {
      any_encoded <<- TRUE
      paste0(collapse = "", sprintf("%%%02x", as.integer(bytes)))
    } else {
      char
    }
  }, character(1))
  paste0("UTF-8''", paste0(encoded, collapse = ""))
}

`%||%` <- function(a, b) {
  if (!is.null(a)) a else b
}
