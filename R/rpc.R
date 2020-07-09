# Make remote procedure calls to the client. Deep breath.

init_rpc <- function(session) {
  session <- unwrap_session(session)

  if (!is.null(session$userData[["tableau-rpc-handlers"]])) {
    return(FALSE)
  }

  url <- session$registerDataObj("tableau-response", session, response_handler())
  session$userData[["tableau-rpc-handlers"]] <- new.env(parent = emptyenv())
  session$sendCustomMessage("shinytableau-rpc-init", list(url = url))
}

begin_request <- function(method, ..., session. = getDefaultReactiveDomain()) {
  session. <- unwrap_session(session.)
  session <- session.

  force(method)
  args <- list(...)
  if (!is.null(names(args))) {
    stop("`begin_request` expects unnamed ... arguments only")
  }

  id <- uuid::UUIDgenerate()

  handlers <- list()

  p <- promises::promise(function(resolve, reject) {
    handlers$resolve <<- resolve
    handlers$reject <<- reject
  })

  session$userData[["tableau-rpc-handlers"]][[id]] <- handlers

  session$sendCustomMessage("shinytableau-rpc",
    list(method = method, args = args, id = id)
  )

  p
}

response_handler <- function(max_bytes = getOption("shinytableau.maxRequestSize", 100000000)) {
  function(data, req) {
    session <- data

    if (req[["REQUEST_METHOD"]] != "POST") {
      return(list(
        status = 405L,
        headers = list("Content-Type" = "text/plain"),
        body = "Method not allowed"
      ))
    }

    if (req[["HTTP_CONTENT_TYPE"]] != "application/json; charset=utf-8") {
      return(list(
        status = 415L,
        headers = list("Content-Type" = "text/plain"),
        body = "Unsupported content type"
      ))
    }

    content_length <- as.integer(req[["HTTP_CONTENT_LENGTH"]])
    if (length(content_length) != 1 || is.na(content_length)) {
      return(list(
        status = 400L,
        headers = list("Content-Type" = "text/plain"),
        body = "Missing or invalid Content-Length header"
      ))
    }

    if (content_length > max_bytes) {
      return(list(
        status = 413L,
        headers = list("Content-Type" = "text/plain"),
        body = "Request size exceeds configured limits on this server"
      ))
    }

    qs <- parseQueryString(req[["QUERY_STRING"]])
    id <- qs$id
    if (is.null(id)) {
      return(NULL) # 404
    }
    handlers <- session$userData[["tableau-rpc-handlers"]][[id]]
    if (is.null(handlers)) {
      return(NULL) # 404
    }
    session$userData[["tableau-rpc-handlers"]][[id]] <- NULL

    body <- req[["rook.input"]]
    bytes <- body$read(max_bytes)
    con <- rawConnection(bytes)
    parsed_body <- tryCatch(
      jsonlite::parse_json(con, simplifyVector = TRUE),
      finally = close(con)
    )

    payload <- parsed_body[["result"]]
    err <- parsed_body[["error"]]

    if (!is.null(err)) {
      handlers$reject(err)
    } else {
      handlers$resolve(payload)
    }

    return(list(
      status = 200L,
      headers = list("Content-Type" = "text/plain"),
      body = "OK"
    ))
  }
}
