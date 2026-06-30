test_that("task tool delegates to a named subagent", {
  worker <- subagent(
    name = "worker",
    description = "Does work.",
    system_prompt = "Work.",
    model = fake_chat(list(assistant_message("child result")))
  )
  agent <- create_deep_agent(
    model = fake_chat(list(
      assistant_tool_call("task", list(description = "do work", subagent = "worker")),
      assistant_message("parent done")
    )),
    subagents = list(worker)
  )
  run <- agent$invoke("delegate")
  expect_equal(run$status, "completed")
  expect_true(any(vapply(run$events, function(event) event$type == "subagent_start", logical(1))))
  expect_true(any(vapply(run$events, function(event) event$type == "subagent_end", logical(1))))
})
