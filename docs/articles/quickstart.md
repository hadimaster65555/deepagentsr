# Quickstart

`deepagentsr` provides a small Deep-Agents-style harness for R. A
`DeepAgent` wraps a model, R tools, a virtual filesystem, subagents,
memory, human approval, and execution events behind one entry point:
[`create_deep_agent()`](https://hadimaster65555.github.io/rdeepagent/reference/create_deep_agent.md).

This vignette uses
[`fake_chat()`](https://hadimaster65555.github.io/rdeepagent/reference/fake_chat.md)
so it can run without a network connection. Use the same agent
configuration with an `ellmer` chat object when you want live model
calls.

## A deterministic first agent

Tools are ordinary R functions wrapped with
[`deep_tool()`](https://hadimaster65555.github.io/rdeepagent/reference/deep_tool.md).
If you do not provide an argument schema, `deepagentsr` infers one from
the function formals and converts it to the provider-specific `ellmer`
schema when needed.

``` r

library(deepagentsr)

calculator <- deep_tool(
  function(x, y) x + y,
  name = "add",
  description = "Add two numbers."
)

agent <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call("write_todos", list(items = list("Call add", "Answer"))),
    assistant_tool_call("add", list(x = 19, y = 23)),
    assistant_message("The result is 42.")
  )),
  tools = list(calculator)
)

result <- agent$invoke("Add 19 and 23.")
result[c("status", "text")]
#> $status
#> [1] "completed"
#> 
#> $text
#> [1] "The result is 42."
```

Every run produces structured events. These events are useful for tests,
logging, UI adapters, and JSONL traces.

``` r

vapply(result$events, function(event) event$type, character(1))
#> [1] "agent_start"   "tool_request"  "todo_update"   "tool_result"  
#> [5] "tool_request"  "tool_result"   "model_message" "agent_end"
```

The thread state includes turns, todos, pending interrupts, summaries,
and other runtime data.

``` r

state <- agent$get_state(result$thread_id)
state$status
#> [1] "completed"
state$todos
#> [[1]]
#> [1] "Call add"
#> 
#> [[2]]
#> [1] "Answer"
```

## Use OpenAI through ellmer

For live calls, pass an `ellmer` chat object or a model factory. The
package does not own provider clients directly; it registers tools with
`ellmer` and lets `ellmer` handle OpenAI, Anthropic, Ollama, and other
providers.

``` r

library(ellmer)
library(deepagentsr)

# Optional for local development when OPENAI_API_KEY is stored in .env.
readRenviron(".env")

calculator <- deep_tool(
  function(x, y) x + y,
  name = "add",
  description = "Add two numbers."
)

agent <- create_deep_agent(
  model = ellmer::chat_openai(model = "gpt-4.1", echo = "none"),
  tools = list(calculator),
  system_prompt = "You are a concise R assistant."
)

agent$invoke("Use the add tool to calculate 19 + 23.")
```

The guarded live test suite has been run against GPT 4.1 and GPT 5
family models, including `gpt-4.1`, `gpt-4.1-mini`, `gpt-4.1-nano`,
`gpt-5`, `gpt-5-mini`, `gpt-5-nano`, `gpt-5.1`, and `gpt-5.2`, subject
to model access on the configured OpenAI account.

## Streaming and async entry points

`agent$stream()` returns execution events for a run. When
[coro](https://github.com/r-lib/coro) is installed it returns a
generator; otherwise it returns a list-like event stream.

``` r

stream_agent <- create_deep_agent(
  model = fake_chat(list(assistant_message("streamed response")))
)

stream <- stream_agent$stream("hello")
events <- if (requireNamespace("coro", quietly = TRUE) &&
  inherits(stream, "coro_generator_instance")) {
  coro::collect(stream)
} else {
  stream
}

vapply(events, function(event) event$type, character(1))
#> [1] "agent_start"   "model_message" "agent_end"
```

`agent$stream_async()` is available when
[promises](https://rstudio.github.io/promises/) is installed and
resolves to the same event stream.

## Runtime context and middleware

Use `context_schema` to require caller-provided runtime fields. Use
`middleware` callbacks to observe every emitted event.

``` r

seen <- character()

context_agent <- create_deep_agent(
  model = fake_chat(list(assistant_message("ok"))),
  context_schema = list(user_id = "character"),
  middleware = list(function(event) {
    seen <<- c(seen, event$type)
  })
)

context_run <- context_agent$invoke(
  "hello",
  context = list(user_id = "user-123")
)

context_run$status
#> [1] "completed"
seen
#> [1] "agent_start"   "model_message" "agent_end"
```
