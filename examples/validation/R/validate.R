#' A class for doing Shiny validation
ShinyValidator <- R6::R6Class("ShinyValidator",
  private = list(
    session = NULL,
    enabled = FALSE,
    rules = NULL
  ),
  public = list(
    initialize = function(session = getDefaultReactiveDomain()) {
      private$session <- session
      private$rules <- reactiveVal(list(), label = "validation_rules")
    },
    add_rule = function(inputId, rule, ...) {
      args <- rlang::list2(...)
      if (is.null(rule)) {
        rule <- function(value) NULL
      }
      if (inherits(rule, "formula")) {
        rule <- rlang::as_function(rule)
      }
      rule <- purrr::partial(rule, ...)
      private$rules(c(isolate(private$rules()), setNames(list(rule), inputId)))
    },
    enable = function() {
      if (!private$enabled) {
        withReactiveDomain(private$session, {
          observe({
            results <- self$validate()
            private$session$sendCustomMessage("validation-jcheng5", results)
          })
        })

        private$enabled <- TRUE
      }
      invisible(self)
    },
    is_valid = function() {
      results <- self$validate()
      all(vapply(results, is.null, logical(1), USE.NAMES = FALSE))
    },
    #' (Advanced) Run validation rules and gather results
    validate = function() {
      results <- list()
      mapply(names(private$rules()), private$rules(), FUN = function(name, rule) {
        try({
          result <- rule(private$session$input[[name]])
          if (!is.null(result)) {
            results <<- c(results, setNames(list(result), name))
          }
        })
      })

      # Now add on a named list where the names are all the inputs we've
      # seen, and the values are all NULL. (We'll remove duplicates in the
      # next step; this ensures that any inputs that don't have validation
      # errors will have their validation state cleared.)
      all_input_names <- unique(names(private$rules()))
      results <- c(results, setNames(rep_len(list(NULL), length(all_input_names)), all_input_names))

      results <- results[!duplicated(names(results))]

      names(results) <- private$session$ns(names(results))
      results
    }
  )
)
