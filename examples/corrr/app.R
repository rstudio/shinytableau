# filetype: shinyApp

library(shiny)
library(shinytableau)
library(thematic)
library(corrr)
library(ggplot2)
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

      get_corr_plot <- function(mat,
                                labels_vec) {

        corr_df <-
          as.data.frame(as.table(mat)) %>%
          dplyr::mutate(Freq = ifelse(Var1 == Var2, NA_real_, Freq)) %>%
          dplyr::mutate(Var1 = factor(Var1, levels = names(labels_vec))) %>%
          dplyr::mutate(Var2 = factor(Var2, levels = rev(names(labels_vec))))


        corr_df %>%
          ggplot2::ggplot(ggplot2::aes(x = Var1, y = Var2, fill = Freq)) +
          ggplot2::geom_tile(color = "white", linejoin = "bevel") +
          ggplot2::scale_fill_gradientn(
            colours = c("blue", "white", "red"),
            na.value = "gray30",
            limits = c(-1, 1)
          ) +
          ggplot2::labs(x = "", y = "") +
          ggplot2::theme_minimal() +
          ggplot2::theme(
            axis.text.x = ggplot2::element_text(
              angle = 90, vjust = 0.5, hjust = 1, size = 10
            ),
            axis.text.y = ggplot2::element_text(size = 10),
            panel.grid = ggplot2::element_blank(),
            legend.direction = "horizontal",
            legend.title = ggplot2::element_blank(),
            legend.position = c(0.5, 1.03),
            plot.margin = ggplot2::unit(c(1, 0.5, 0, 0), "cm"),
            legend.key.width = ggplot2::unit(2.0, "cm"),
            legend.key.height = ggplot2::unit(3.0, "mm")
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

      labels_vec <- seq_along(colnames(corr_pearson))
      names(labels_vec) <- colnames(corr_pearson)

      corr_plot <- get_corr_plot(mat = corr_pearson, labels_vec = labels_vec)
      corr_plot
    }
  })
}

config_ui <- fillPage(
  fillCol(flex = c(1, NA),
    miniUI::miniContentPanel(
      textInput("title", "Title", ""),
      choose_data_ui("data", "Choose data"),
      tableOutput("preview")
    ),
    htmltools::tags$div(style = "text-align: right; padding: 8px 15px; height: 50px; border-top: 1px solid #DDD;",
      actionButton("ok", "OK", class = "btn-primary"),
      actionButton("cancel", "Cancel"),
      actionButton("apply", "Apply")
    )
  )
)

config_server <- function(input, output, session) {
  data_spec <- choose_data("data")

  data <- reactive_tableau_data(data_spec, options = list(maxRows = 3))

  output$preview <- renderTable({
    data()
  })

  save_settings <- function() {
    update_tableau_settings(
      plot_title = input$title,
      data_spec = data_spec(),
      save. = TRUE
      # TODO: add. = FALSE
    )
  }

  observeEvent(input$ok, {
    save_settings()
    tableau_close_dialog()
  })
  observeEvent(input$cancel, {
    tableau_close_dialog()
  })
  observeEvent(input$apply, {
    save_settings()
  })
}

tableau_extension(
  manifest, ui, server, config_ui, config_server,
  options = list(port = 2468)
)
