test_that("file resolution works", {

  expect_null(resolve_file(NULL, ".", "fieldname"))

  expect_identical(
    resolve_file(list(
      file = "default_icon.png",
      package = "shinytableau"
    ), ".", "fieldname"),
    system.file("default_icon.png", package = "shinytableau", mustWork = TRUE)
  )

  expect_identical(
    resolve_file(list(
      file = "default_icon.png"
    ), system.file(package = "shinytableau", mustWork = TRUE), "fieldname"),
    system.file("default_icon.png", package = "shinytableau", mustWork = TRUE)
  )

  expect_identical(
    resolve_file("default_icon.png",
      system.file(package = "shinytableau", mustWork = TRUE), "fieldname"),
    system.file("default_icon.png", package = "shinytableau", mustWork = TRUE)
  )

  expect_error(resolve_file(1, ".", "fieldname1"), "fieldname1")
  expect_error(resolve_file("does-not-exist", ".", "fieldname2"))
  expect_error(resolve_file(list(file = "does-not-exist", package = "foo"), ".", "fieldname3"))
  expect_error(resolve_file(list(file = "does-not-exist", package = "shinytableau"), ".", "fieldname4"))
})
