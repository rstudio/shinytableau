#' @export
tableau_setting <- function(name, default = NULL, session = getDefaultReactiveDomain()) {
  value <- session$input[[paste0("shinytableau-setting-", name)]]
  if (is.null(value)) default else value
}

#' @export
update_tableau_settings <- function(..., save. = FALSE, session = getDefaultReactiveDomain()) {
  session$sendCustomMessage(type = "shinytableau-setting-update",
    message = list(
      settings = list(...),
      save = save.
    )
  )
}

#' @export
tableau_settings_all <- function(session = getDefaultReactiveDomain()) {
  session$input[["shinytableau-settings"]]
}

#' @export
reactive_tableau_worksheet <- function(name,
  ignore_aliases = FALSE,
  ignore_selection = FALSE,
  session = getDefaultReactiveDomain()) {

  session$sendCustomMessage(type = "shinytableau-subscribe-worksheet",
    message = list(
      name = name,
      options = list(
        ignoreAliases = ignore_aliases,
        ignoreSelection = ignore_selection
      )
    )
  )
}
