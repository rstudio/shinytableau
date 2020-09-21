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

#' Read Tableau extension settings
#'
#' Call `tableau_setting()` from an extension's `server` and `config_server`
#' functions to read settings that were previously set via
#' [update_tableau_settings_async()].
#'
#' A typical extension will call [update_tableau_settings_async()] from
#' `config_server` to write settings, and [tableau_setting()] from `server` to
#' read settings.
#'
#' Note that both `tableau_setting()` and `tableau_settings_all()` are reactive
#' reads; in order to call these functions you must be inside a reactive context
#' (i.e. reactive expression, reactive observer, output render expression, or
#' [isolate()]), and future updates to a setting that was read will cause
#' reactive invalidation.
#'
#' @param name The name of a setting to retrieve.
#' @param default The value to return if the requested setting has not been set.
#' @param session The Shiny `session` object. (You should probably just use the
#'   default.)
#' @return For `tableau_setting()`, an object that was previously saved via
#'   `update_tableau_settings_async`, or the `default` value. For
#'   `tableau_settings_all()`, a named list containing all of the settings.
#'
#' @export
tableau_setting <- function(name, default = NULL, session = shiny::getDefaultReactiveDomain()) {
  session <- unwrap_session(session)

  value <- session$input[[paste0("shinytableau-setting-", name)]]
  if (is.null(value)) default else value
}

#' Write Tableau extension settings
#'
#' Call `update_tableau_settings_async()` from an extension's `config_server`
#' function to write settings that can be read, now and in the future, by
#' [tableau_setting()].
#'
#' While the settings reading functions---[tableau_setting()] and
#' [tableau_settings_all()]---are reactive, `update_tableau_settings_async()` is
#' not. Calling it does not cause any reactive dependencies to be taken.
#'
#' As implied by the function name, `update_tableau_settings_async()` does its
#' work [asynchronously](https://rstudio.github.io/promises/) (as the actual
#' persisting of settings must happen through the Tableau Extension API in the
#' web browser, not directly in R). You can usually ignore this fact, except
#' that you should ensure that if this function is being called from within an
#' [observe()] or [observeEvent()], that the promise object it returns is the
#' return value of the observer code block. (This is to alert Shiny to the fact
#' that this observer can't really be considered done with its execution until
#' the `update_tableau_settings_async()` task is completely finished.)
#'
#' @param ... Settings to be persisted, as named arguments. The value should be
#'   suitable for encoding as JSON using `jsonlite::toJSON(auto_unbox = TRUE)`.
#' @param add. A logical (`TRUE`/`FALSE`) value. If `FALSE` (the default), the
#'   settings provided in `...` should replace all existing settings for this
#'   extension. If `TRUE`, the settings provided in `...` are merged with the
#'   settings that already exist.
#' @param session. The Shiny `session` object. (You should probably just use the
#'   default.)
#'
#' @return A [promises::promise] object. See Details.
#'
#' @export
update_tableau_settings_async <- function(..., add. = FALSE, session. = shiny::getDefaultReactiveDomain()) {
  session. <- unwrap_session(session.)

  begin_request("saveSettings", rlang::list2(...), list(save = TRUE, add = add.), session. = session.)
}

#' @rdname tableau_setting
#' @export
tableau_settings_all <- function(session = shiny::getDefaultReactiveDomain()) {
  session <- unwrap_session(session)

  session$input[["shinytableau-settings"]]
}
