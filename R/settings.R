#' @export
tableau_setting <- function(name, default = NULL, session = getDefaultReactiveDomain()) {
  session$input[[paste0("shinytableau-setting-", name)]]
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
