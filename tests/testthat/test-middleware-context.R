test_that("middleware receives emitted events", {
  seen <- new.env(parent = emptyenv())
  seen$types <- character()
  agent <- create_deep_agent(
    model = fake_chat(list(assistant_message("done"))),
    middleware = list(function(event) {
      seen$types <- c(seen$types, event$type)
    })
  )
  agent$invoke("hello")
  expect_true("agent_start" %in% seen$types)
  expect_true("agent_end" %in% seen$types)
})

test_that("context_schema validates context", {
  agent <- create_deep_agent(
    model = fake_chat(list(assistant_message("done"))),
    context_schema = list(user_id = "character")
  )
  expect_error(agent$invoke("hello"), "missing required field")
  expect_no_error(agent$invoke("hello", context = list(user_id = "u1")))
})
