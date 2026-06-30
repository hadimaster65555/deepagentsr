test_that("large tool results are offloaded", {
  big <- deep_tool(
    function() paste(rep("large output", 100), collapse = "\n"),
    name = "big",
    description = "Return a large value."
  )
  backend <- memory_backend()
  agent <- create_deep_agent(
    model = fake_chat(list(
      assistant_tool_call("big", list()),
      assistant_message("done")
    )),
    tools = list(big),
    backend = backend,
    context_budget = context_budget(offload_tokens = 10)
  )

  run <- agent$invoke("call big")
  expect_equal(run$status, "completed")
  files <- backend$list("/internal/offloads", recursive = TRUE)
  expect_true(any(grepl("\\.txt$", files$path)))
  expect_true(any(vapply(run$events, function(event) event$type == "context_offload", logical(1))))
})

test_that("context manager compacts old turns and preserves transcript", {
  backend <- memory_backend()
  agent <- create_deep_agent(
    model = fake_chat(list(
      assistant_tool_call("write_file", list(path = "/a.txt", content = paste(rep("alpha", 80), collapse = " "))),
      assistant_tool_call("read_file", list(path = "/a.txt")),
      assistant_message("done")
    )),
    backend = backend,
    context_budget = context_budget(max_input_tokens = 80, summarize_at = 0.3, keep_recent = 0.25)
  )
  run <- agent$invoke("create and read a large file")
  expect_equal(run$status, "completed")
  expect_true(any(vapply(run$state$turns, function(turn) identical(turn$role, "summary"), logical(1))))
  transcripts <- backend$list("/internal/transcripts", recursive = TRUE)
  expect_true(any(grepl("\\.md$", transcripts$path)))
})
