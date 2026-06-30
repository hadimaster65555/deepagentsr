test_that("filesystem backend stays inside root", {
  root <- tempfile("deepagentsr-fs-")
  backend <- filesystem_backend(root)
  backend$write("/a/b.txt", "safe")
  expect_equal(backend$read("/a/b.txt"), "safe")
  expect_error(backend$read("../outside"), "Path traversal")
})

test_that("filesystem backend denies secret-like paths by default", {
  root <- tempfile("deepagentsr-fs-")
  backend <- filesystem_backend(root)
  expect_error(backend$write("/.env", "TOKEN=x"), "secret-like")
})

test_that("filesystem backend blocks symlink escapes when supported", {
  skip_on_os("windows")
  root <- tempfile("deepagentsr-fs-")
  outside <- tempfile("deepagentsr-outside-")
  dir.create(root)
  dir.create(outside)
  file.symlink(outside, file.path(root, "link"))
  backend <- filesystem_backend(root, deny_secret_paths = FALSE)
  expect_error(backend$write("/link/out.txt", "nope"), "escapes")
})
