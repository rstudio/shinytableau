options(shiny.autoreload = TRUE)

library(shiny)
library(htmltools)
library(magrittr)

ui <- fluidPage(
  tags$script(src = "validation.js"),
  uiOutput("ui"),
  hr(),
  actionButton("redraw", "Redraw UI")
)

server <- function(input, output, session) {
  sv <- ShinyValidator$new()
  sv$add_rule("title", need, message = "This field is required")
  sv$add_rule("cars", need, label = "Cars")
  sv$add_rule("species", need, label = "Species")
  sv$add_rule("pass1", need, label = "Password")
  sv$add_rule("pass1", function(value) {
    if (nchar(value) < 8) "Password is too short"
  })
  sv$add_rule("pass2", ~ if (!identical(., input$pass1)) "Passwords must match")

  # sv$require
  # sv$check

  output$ui <- renderUI({
    input$redraw
    list(
      textInput("title", "Title", value = isolate(input$title)),
      checkboxGroupInput("cars", "Cars", choices = rownames(mtcars)[1:3], selected = isolate(input$cars)),
      selectInput("species", "Iris species", choices = unique(iris$Species), selected = isolate(input$species), multiple = TRUE),
      passwordInput("pass1", "Password", value = isolate(input$pass1)),
      passwordInput("pass2", "Password (confirm)", value = isolate(input$pass2)),
      actionButton("go", "Submit")
    )
  })

  observeEvent(input$go, {
    sv$enable()

    if (sv$is_valid()) {
      message("Action performed")
    } else {
      message("Action aborted")
    }
  })
}

shinyApp(ui, server)
