#' A class for doing Shiny validation
ShinyValidator <- R6::R6Class("ShinyValidator",
  private = list(
    session = NULL,
    enabled = FALSE,
    observer_handle = NULL,
    priority = numeric(0),
    rules = NULL,
    validators = list()
  ),
  public = list(
    initialize = function(priority = 1000, session = getDefaultReactiveDomain()) {
      private$session <- session
      private$priority <- priority
      private$rules <- reactiveVal(list(), label = "validation_rules")
    },
    add_validator = function(validator) {
      if (!inherits(validator, "ShinyValidator")) {
        stop("add_validator was called with an invalid `validator` argument; ShinyValidator object expected")
      }
      private$validators <- c(private$validators, list(validator))
      invisible(self)
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
      invisible(self)
    },
    enable = function() {
      for (validator in private$validators) {
        validator$enable()
      }
      if (!private$enabled) {
        withReactiveDomain(private$session, {
          private$observer_handle <- observe({
            results <- self$validate(include_child_validators = FALSE)
            private$session$sendCustomMessage("validation-jcheng5", results)
          }, priority = private$priority)
        })

        private$enabled <- TRUE
      }
      invisible(self)
    },
    disable = function() {
      for (validator in private$validators) {
        validator$disable()
      }
      if (private$enabled) {
        private$observer_handle$destroy()
        private$observer_handle <- NULL
        private$enabled <- FALSE
        results <- self$validate(include_child_validators = FALSE)
        results <- lapply(results, function(x) NULL)
        private$session$sendCustomMessage("validation-jcheng5", results)
      }
    },
    is_valid = function(include_child_validators = TRUE) {
      results <- self$validate(include_child_validators = include_child_validators)
      all(vapply(results, is.null, logical(1), USE.NAMES = FALSE))
    },
    #' (Advanced) Run validation rules and gather results
    validate = function(include_child_validators = TRUE) {
      dependency_results <- list()
      if (include_child_validators) {
        for (validator in private$validators) {
          dependency_results <- merge_results(dependency_results, validator$validate())
        }
      }
      # A vector of namespace-qualified input IDs that have failed validation
      # before our rules even start executing
      failed <- names(dependency_results[!vapply(dependency_results, is.null, logical(1))])

      results <- list()
      mapply(names(private$rules()), private$rules(), FUN = function(name, rule) {
        fullname <- private$session$ns(name)
        # Short-circuit
        if (fullname %in% failed) return()

        try({
          result <- rule(private$session$input[[name]])
          if (!is.null(result) && (!is.character(result) || length(result) != 1)) {
            stop("Result of '", name, "' validation was not a single-character vector")
          }
          # Note that if there's an error in rule(), we won't get to the next
          # line
          if (!is.null(result)) {
            results <<- c(results, setNames(list(result), fullname))
            failed <<- c(failed, fullname)
          }
        })
      })

      # Now add on a named list where the names are all the inputs we've
      # seen, and the values are all NULL. (We'll remove duplicates in the
      # next step; this ensures that any inputs that don't have validation
      # errors will have their validation state cleared.)
      all_input_names <- unique(private$session$ns(names(private$rules())))
      results <- c(results, setNames(rep_len(list(NULL), length(all_input_names)), all_input_names))
      results <- results[!duplicated(names(results))]

      results <- merge_results(dependency_results, results)

      results
    }
  )
)

merge_results <- function(resultsA, resultsB) {
  results <- c(resultsA, resultsB)
  # Reorder to put non-NULLs first; then dedupe
  has_error <- !vapply(results, is.null, logical(1))
  results <- results[c(which(has_error), which(!has_error))]
  results <- results[!duplicated(names(results))]
  results
}
