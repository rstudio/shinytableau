#' @export
tableau_spinner <- function(fill = TRUE) {
  div(class = "tableau-spinner",
    class = if (isTRUE(fill)) "tableau-spinner-fill",
    role = "progressbar",

    div(class = "slice gradient", "aria-hidden" = "true"),
    div(class = "slice bottom-left", "aria-hidden" = "true"),
    div(class = "slice bottom-right", "aria-hidden" = "true"),
    div(class = "center", "aria-hidden" = "true")
  )
}
