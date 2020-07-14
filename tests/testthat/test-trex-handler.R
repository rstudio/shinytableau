test_that("Infer URL", {
  req <- list(
    rook.url_scheme = "http",
    SCRIPT_NAME = "",
    PATH_INFO = "/",
    SERVER_NAME = "127.0.0.1",
    SERVER_PORT = "80"
  )

  extend <- function(lst, ...) {
    args <- list(...)
    mapply(names(args), args, FUN = function(nm, value) {
      lst[[nm]] <<- value
    })
    lst
  }

  # Note: localhost, not 127.0.0.1 or [::1]
  expect_identical(infer_embed_url(req), "http://localhost/?mode=embed")
  expect_identical(infer_embed_url(extend(req, SERVER_NAME = "[::1]")), "http://localhost/?mode=embed")

  expect_identical(
    infer_embed_url(extend(req, rook.url_scheme = "https")),
    "https://localhost:80/?mode=embed")

  expect_identical(
    infer_embed_url(extend(req, SERVER_PORT = "3939")),
    "http://localhost:3939/?mode=embed")

  expect_identical(
    infer_embed_url(extend(req, HTTP_HOST = "host.example.com:80")),
    "http://host.example.com/?mode=embed")

  expect_identical(
    infer_embed_url(extend(req, HTTP_HOST = "host.example.com:8080")),
    "http://host.example.com:8080/?mode=embed")

  req$HTTP_HOST <- "host.example.com:80"

  req <- extend(req,
    HTTP_X_FORWARDED_PROTO = "https",
    HTTP_X_FORWARDED_HOST = "proxy_server",
    HTTP_X_FORWARDED_PORT = "443")

  expect_identical(
    infer_embed_url(req),
    "https://proxy_server/?mode=embed")

  expect_identical(
    infer_embed_url(extend(req,
      HTTP_X_REDX_FRONTEND_NAME = "example.shinyapps.io/appname/",
      HTTP_RSTUDIO_CONNECT_APP_BASE_URL = "https://connect2/a/b/?c=d",
      HTTP_X_RSC_REQUEST = "https://connect/foo/bar/?qux=quux"
      )),
    "https://connect/foo/bar/?mode=embed")

  expect_identical(
    infer_embed_url(extend(req,
      HTTP_X_REDX_FRONTEND_NAME = "example.shinyapps.io/appname/",
      HTTP_RSTUDIO_CONNECT_APP_BASE_URL = "https://connect2/a/b/?c=d"
    )),
    "https://connect2/a/b/?mode=embed")


  expect_identical(
    infer_embed_url(extend(req,
      HTTP_X_REDX_FRONTEND_NAME = "example.shinyapps.io/appname/"
    )),
    "https://example.shinyapps.io/appname/?mode=embed")
})
