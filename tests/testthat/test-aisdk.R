test_that("aisdk_tool wraps an aisdk-like agent", {
  AgentLike <- R6::R6Class(
    "AgentLike",
    public = list(
      name = "worker",
      description = "Does delegated work.",
      run = function(task, context = NULL, model = NULL, max_steps = 10, ...) {
        paste("ran", task, context$topic %||% "")
      }
    )
  )
  tool <- aisdk_tool(AgentLike$new())
  expect_equal(tool$name, "worker_agent")
  expect_match(tool$fun("task", list(topic = "alpha")), "ran task alpha")
})

test_that("aisdk_subagent delegates through task tool", {
  AgentLike <- R6::R6Class(
    "AgentLike",
    public = list(
      name = "worker",
      description = "Does delegated work.",
      run = function(task, context = NULL, model = NULL, max_steps = 10, ...) {
        paste("child", task)
      }
    )
  )
  agent <- create_deep_agent(
    model = fake_chat(list(
      assistant_tool_call("task", list(description = "do it", subagent = "worker")),
      assistant_message("done")
    )),
    subagents = list(aisdk_subagent(AgentLike$new()))
  )
  run <- agent$invoke("delegate")
  expect_equal(run$status, "completed")
  expect_true(any(vapply(run$events, function(event) event$type == "subagent_end", logical(1))))
})
