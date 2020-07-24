options(shiny.autoreload = TRUE)

library(shiny)
library(htmltools)
library(magrittr)
library(shinyvalidate)

ui <- fluidPage(
  uiOutput("ui"),
  actionButton("go", "Submit", class = "btn-primary"),
  actionButton("reset", "Reset"),
  hr(),
  actionButton("redraw", "Redraw UI")
)

server <- function(input, output, session) {
  pw <- password_input("password")

  iv <- InputValidator$new()
  iv$add_validator(pw$validator)
  iv$add_rule("title", need, "This field is required")
  iv$add_rule("cars", need, label = "Cars")
  iv$add_rule("species", need, label = "Species")

  # iv$require
  # iv$check

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
    iv$enable()

    if (iv$is_valid()) {
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
    iv$disable()
  }
}

shinyApp(ui, server)
