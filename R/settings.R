# Wraps the current session, in case we're being called from within a module;
# it's important that we use the top-level session, otherwise all of the ids
# will be wrong.
wrap_session <- function(session) {
  session$userData[["tableau-session"]] <- session
  session
}

# Unwraps the current session (see wrap_session).
unwrap_session <- function(session) {
  session <- session$userData[["tableau-session"]]
  if (is.null(session)) {
    stop("shinytableau session not initialized. Are you trying to use tableau functions outside of a shinytableau extension?")
  }
  session
}

#' @export
tableau_setting <- function(name, default = NULL, session = getDefaultReactiveDomain()) {
  session <- unwrap_session(session)

  value <- session$input[[paste0("shinytableau-setting-", name)]]
  if (is.null(value)) default else value
}

#' @export
update_tableau_settings <- function(..., save. = FALSE, session = getDefaultReactiveDomain()) {
  session <- unwrap_session(session)

  session$sendCustomMessage(type = "shinytableau-setting-update",
    message = list(
      settings = list(...),
      save = save.
    )
  )
}

#' @export
tableau_settings_all <- function(session = getDefaultReactiveDomain()) {
  session <- unwrap_session(session)

  session$input[["shinytableau-settings"]]
}
