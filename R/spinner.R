tableau_spinner <- function(fill = TRUE) {
  htmltools::div(class = "tableau-spinner",
    class = if (isTRUE(fill)) "tableau-spinner-fill",
    role = "progressbar",

    htmltools::div(class = "slice gradient", "aria-hidden" = "true"),
    htmltools::div(class = "slice bottom-left", "aria-hidden" = "true"),
    htmltools::div(class = "slice bottom-right", "aria-hidden" = "true"),
    htmltools::div(class = "center", "aria-hidden" = "true")
  )
}
