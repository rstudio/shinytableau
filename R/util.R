merge_defaults <- function(options, defaults = NULL) {
  if (!is.list(options) || !is.list(defaults)) {
    stop("Options must be provided in list form")
  }

  defaults_to_use <- !names(defaults) %in% names(options)
  c(defaults[defaults_to_use], options)
}
