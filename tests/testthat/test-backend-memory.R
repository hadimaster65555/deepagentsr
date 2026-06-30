test_that("memory backend writes, reads, edits, lists, globs, and greps", {
  backend <- memory_backend()
  backend$write("/notes/a.txt", "hello world")
  backend$write("/notes/b.md", "goodbye world")

  expect_true(backend$exists("/notes/a.txt"))
  expect_equal(backend$read("/notes/a.txt"), "hello world")

  backend$edit("/notes/a.txt", "hello", "hi")
  expect_equal(backend$read("/notes/a.txt"), "hi world")

  listing <- backend$list("/notes")
  expect_setequal(listing$path, c("/notes/a.txt", "/notes/b.md"))

  expect_equal(backend$glob("*.txt", "/notes"), "/notes/a.txt")

  hits <- backend$grep("world", "/notes")
  expect_equal(nrow(hits), 2)
})

test_that("memory backend blocks traversal", {
  backend <- memory_backend()
  expect_error(backend$read("../secret"), "Path traversal")
})
