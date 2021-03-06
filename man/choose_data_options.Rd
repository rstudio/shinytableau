% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/module-data.R
\name{choose_data_options}
\alias{choose_data_options}
\title{Options for the \code{choose_data} module}
\usage{
choose_data_options(
  aggregation = c("ask", "summary", "underlying", "datasource")
)
}
\arguments{
\item{aggregation}{A character vector indicating what kind of data is allowed
to be selected from a worksheet:
\itemize{
\item \code{"summary"} (i.e. aggregated),
\item \code{"underlying"} (i.e. row-level), and/or
\item \code{"datasource"} (the logical
table(s) from which the underlying data is derived).
}

A vector of length 1, 2, or 3 may be passed; if length 1, then the user
will not be shown a choice.

The special value \code{"ask"} (the default) is equivalent to
\code{c("summary", "underlying", "datasource")}.}
}
\description{
The \code{\link[=choose_data]{choose_data()}} module has an \code{options} parameter. Use the
\code{choose_data_options} function to construct such option objects.
}
\seealso{
\code{\link[=choose_data]{choose_data()}}
}
