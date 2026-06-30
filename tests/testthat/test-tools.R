test_that("deep_tool registers and executes", {
  tool <- deep_tool(
    function(x, y) x + y,
    name = "add",
    description = "Add numbers."
  )
  registry <- deepagentsr:::ToolRegistry$new(list(tool))
  expect_true(registry$has("add"))
  expect_equal(registry$execute("add", list(x = 2, y = 3)), 5)
})

test_that("agent invokes fake chat tool loop", {
  add <- deep_tool(function(x, y) x + y, name = "add", description = "Add.")
  agent <- create_deep_agent(
    model = fake_chat(list(
      assistant_tool_call("add", list(x = 2, y = 5)),
      assistant_message("7")
    )),
    tools = list(add)
  )
  result <- agent$invoke("add")
  expect_equal(result$status, "completed")
  expect_equal(result$text, "7")
  expect_true(any(vapply(result$events, function(event) event$type == "tool_result", logical(1))))
})

test_that("ellmer conversion infers missing schemas for tool formals", {
  skip_if_not_installed("ellmer")
  tool <- deep_tool(
    function(question, options = NULL) paste(question, paste(options, collapse = ", ")),
    name = "ask_user_like",
    description = "Ask a question."
  )
  expect_true(inherits(as_ellmer_tool(tool), "ellmer::ToolDef"))
})

test_that("ellmer-like chat can register all built-in tools", {
  skip_if_not_installed("ellmer")
  ChatLike <- R6::R6Class(
    "ChatLike",
    public = list(
      tools = NULL,
      provider = NULL,
      initialize = function() {
        self$provider <- ellmer::chat_openai(
          credentials = function() "dummy",
          model = "gpt-4.1"
        )$get_provider()
      },
      register_tools = function(tools) {
        for (tool in tools) {
          ellmer:::as_json(self$provider, tool@arguments)
        }
        self$tools <- tools
        invisible(self)
      },
      chat = function(input) "ok"
    )
  )
  agent <- create_deep_agent(model = ChatLike$new())
  run <- agent$invoke("hello")
  expect_equal(run$text, "ok")
})

test_that("ellmer-like chat executes tools through harness wrapper", {
  skip_if_not_installed("ellmer")
  ChatCallsTool <- R6::R6Class(
    "ChatCallsTool",
    public = list(
      tools = NULL,
      callback = NULL,
      set_tools = function(tools) {
        self$tools <- tools
        invisible(self)
      },
      on_tool_request = function(callback) {
        self$callback <- callback
        function() invisible()
      },
      chat = function(input) {
        req <- ellmer:::ContentToolRequest(
          id = "call-1",
          name = "add",
          arguments = list(x = 40, y = 2),
          tool = self$tools$add,
          extra = list()
        )
        self$callback(req)
        paste("model saw", self$tools$add(x = 40, y = 2))
      }
    )
  )
  add <- deep_tool(function(x, y) x + y, name = "add", description = "Add.")
  agent <- create_deep_agent(model = ChatCallsTool$new(), tools = list(add))
  run <- agent$invoke("add")
  expect_equal(run$status, "completed")
  expect_equal(run$text, "model saw 42")
  expect_true(any(vapply(run$events, function(event) event$type == "tool_request", logical(1))))
  expect_true(any(vapply(run$events, function(event) event$type == "tool_result", logical(1))))
})

test_that("ellmer-like chat interrupts before wrapper tool side effects", {
  skip_if_not_installed("ellmer")
  touched <- new.env(parent = emptyenv())
  touched$value <- FALSE
  ChatInterrupts <- R6::R6Class(
    "ChatInterrupts",
    public = list(
      tools = NULL,
      callback = NULL,
      set_tools = function(tools) {
        self$tools <- tools
        invisible(self)
      },
      on_tool_request = function(callback) {
        self$callback <- callback
        function() invisible()
      },
      chat = function(input) {
        req <- ellmer:::ContentToolRequest(
          id = "call-1",
          name = "send_email",
          arguments = list(to = "a@example.com"),
          tool = self$tools$send_email,
          extra = list()
        )
        self$callback(req)
        self$tools$send_email(to = "a@example.com")
      }
    )
  )
  send <- deep_tool(
    function(to) {
      touched$value <- TRUE
      "sent"
    },
    name = "send_email",
    description = "Send email.",
    interrupt = TRUE
  )
  agent <- create_deep_agent(model = ChatInterrupts$new(), tools = list(send))
  run <- agent$invoke("send")
  expect_equal(run$status, "interrupted")
  expect_false(touched$value)
  expect_equal(run$pending$tool, "send_email")
})

test_that("inferred object schemas convert for OpenAI provider", {
  skip_if_not_installed("ellmer")
  provider <- ellmer::chat_openai(
    credentials = function() "dummy",
    model = "gpt-4.1"
  )$get_provider()
  tool <- deep_tool(
    function(description, subagent = NULL, context = list()) "ok",
    name = "task_like",
    description = "Delegate work."
  )
  ellmer_tool <- as_ellmer_tool(tool)
  expect_no_error(ellmer:::as_json(provider, ellmer_tool@arguments))
})
