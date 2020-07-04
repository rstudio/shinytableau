shiny::registerInputHandler("tableau_datatable", function(value, session, name) {
  as.data.frame(lapply(value, unlist), stringsAsFactors = FALSE)
}, force = TRUE)
