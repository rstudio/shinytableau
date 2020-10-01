# filetype: shinyApp

library(shiny)
library(shinytableau)
library(dplyr)
library(thematic)
library(corrplot)
library(promises)

manifest <- tableau_manifest_from_yaml("manifest.yml")

ui <- function(req) {
  fillPage(
    fillCol(
      plotOutput("plot", height = "100%")
    )
  )
}

server <- function(input, output, session) {
  df <- reactive_tableau_data(reactive(tableau_setting("data_spec")))

  output$plot <- renderPlot({

    df() %...>% {

      get_r_column_names_types <- function(tbl) {

        suppressWarnings(
          column_names_types <-
            tbl %>%
            utils::head(1) %>%
            dplyr::collect() %>%
            vapply(
              FUN.VALUE = character(1),
              FUN = function(x) class(x)[1]
            )
        )

        list(
          col_names = names(column_names_types),
          r_col_types = unname(unlist(column_names_types))
        )
      }

      tbl_info <- get_r_column_names_types(tbl = .)
      col_names <- tbl_info$col_names
      col_types <- tbl_info$r_col_types

      columns_numeric <- col_names[col_types %in% c("integer", "numeric")]
      data_corr <- dplyr::select(., dplyr::one_of(columns_numeric))

      corr_pearson <- stats::cor(data_corr, method = "pearson", use = "pairwise.complete.obs")

      cols_to_remove <-
        vapply(
          colnames(corr_pearson), FUN.VALUE = logical(1), USE.NAMES = TRUE,
          FUN = function(x) {

            corr_pearson %>% dplyr::as_tibble() %>% dplyr::pull({{ x }}) %>%
              is.na() %>% all()
          }
        ) %>% which() %>% names()

      if (length(cols_to_remove) > 0) {

        data_corr <- data_corr %>% select(-{{ cols_to_remove }})
        corr_pearson <- stats::cor(data_corr, method = "pearson", use = "pairwise.complete.obs")
      }

      corrplot::corrplot(
        corr = as.matrix(corr_pearson),
        type = "lower", order = "hclust", tl.col = "black", tl.srt = 45
      )
    }
  })
}

config_ui <- function(req) {
  tagList(
    choose_data_ui("data", "Choose data"),
    tableOutput("preview")
  )
}

config_server <- function(input, output, session, iv) {
  data_spec <- choose_data("data", iv = iv)

  data <- reactive_tableau_data(data_spec, options = list(maxRows = 3))

  output$preview <- renderTable({
    data()
  })

  save_settings <- function() {
    update_tableau_settings_async(
      data_spec = data_spec()
    )
  }
  return(save_settings)
}

tableau_extension(
  manifest, ui, server, config_ui, config_server,
  options = list(port = 2468)
)
