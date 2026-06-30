test_that("rds checkpointer saves and restores completed thread state", {
  path <- tempfile(fileext = ".rds")
  cp <- rds_checkpointer(path)
  agent <- create_deep_agent(
    model = fake_chat(list(assistant_message("done"))),
    checkpointer = cp
  )
  run <- agent$invoke("hello")
  expect_true(file.exists(path))
  expect_true(run$thread_id %in% cp$list_threads())

  restored <- create_deep_agent(
    model = fake_chat(list(assistant_message("unused"))),
    checkpointer = cp
  )
  restored$load_state(run$thread_id)
  state <- restored$get_state(run$thread_id)
  expect_equal(state$status, "completed")
  expect_true(any(vapply(state$turns, function(turn) identical(turn$content, "done"), logical(1))))
})
