options(shiny.autoreload = TRUE)

library(shiny)
library(htmltools)
library(magrittr)

ui <- fluidPage(
  tags$script(src = "validation.js"),
  uiOutput("ui"),
  actionButton("go", "Submit", class = "btn-primary"),
  actionButton("reset", "Reset"),
  hr(),
  actionButton("redraw", "Redraw UI")
)

server <- function(input, output, session) {
  pw <- password_input("password")

  sv <- ShinyValidator$new()
  sv$add_validator(pw$validator)
  sv$add_rule("title", need, message = "This field is required")
  sv$add_rule("cars", need, label = "Cars")
  sv$add_rule("species", need, label = "Species")

  # sv$require
  # sv$check

  output$ui <- renderUI({
    input$redraw
    list(
      textInput("title", "Title", value = isolate(input$title)),
      checkboxGroupInput("cars", "Cars", choices = rownames(mtcars)[1:3], selected = isolate(input$cars)),
      selectInput("species", "Iris species", choices = unique(iris$Species), selected = isolate(input$species), multiple = TRUE),
      password_input_ui("password")
    )
  })

  observeEvent(input$go, {
    sv$enable()

    if (sv$is_valid()) {
      message("Action performed")
      reset_form()
      showNotification("Something good happened!", type = "message")
    } else {
      message("Action aborted")
      showNotification("Please correct errors and try again!", type = "warning")
    }
  })

  observeEvent(input$reset, {
    reset_form()
  })

  reset_form <- function() {
    updateTextInput(session, "title", value = "")
    updateCheckboxGroupInput(session, "cars", selected = character(0))
    updateSelectInput(session, "species", selected = character(0))
    pw$reset()
    sv$disable()
  }
}

shinyApp(ui, server)
