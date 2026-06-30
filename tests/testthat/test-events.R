test_that("events export and import as jsonl", {
  agent <- create_deep_agent(
    model = fake_chat(list(assistant_message("done")))
  )
  run <- agent$invoke("hello")
  path <- tempfile(fileext = ".jsonl")
  export_events_jsonl(agent, path, thread_id = run$thread_id)
  events <- read_events_jsonl(path)
  expect_true(length(events) >= 2)
  expect_true(any(vapply(events, function(event) event$type == "agent_end", logical(1))))
})

test_that("stream returns execution events", {
  agent <- create_deep_agent(
    model = fake_chat(list(assistant_message("streamed")))
  )
  stream <- agent$stream("hello")
  events <- if (inherits(stream, "coro_generator") || inherits(stream, "coro_generator_instance")) {
    coro::collect(stream)
  } else {
    stream
  }
  expect_true(any(vapply(events, function(event) event$type == "agent_start", logical(1))))
  expect_true(any(vapply(events, function(event) event$type == "agent_end", logical(1))))
})

test_that("stream_async returns a promise when promises is installed", {
  skip_if_not_installed("promises")
  agent <- create_deep_agent(
    model = fake_chat(list(assistant_message("async")))
  )
  promise <- agent$stream_async("hello")
  expect_s3_class(promise, "promise")
})
