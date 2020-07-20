password_input_ui <- function(id, pass1_value = "", pass2_value = pass1_value) {
  ns <- NS(id)
  tagList(
    passwordInput(ns("pass1"), "Password", value = pass1_value),
    passwordInput(ns("pass2"), "Password (confirm)", value = pass2_value)
  )
}

password_input <- function(id) {
  moduleServer(id, function(input, output, session) {
    sv <- ShinyValidator$new()
    sv$add_rule("pass1", need, label = "Password")
    sv$add_rule("pass1", function(value) {
      if (nchar(value) < 8) "Password is too short"
    })
    sv$add_rule("pass2", ~ if (!identical(., input$pass1)) "Passwords must match")

    return(list(
      value = reactive({
        req(sv$is_valid())
        input$pass1
      }),
      validator = sv,
      reset = function() {
        updateTextInput(session, "pass1", value = "")
        updateTextInput(session, "pass2", value = "")
      }
    ))
  })
}
