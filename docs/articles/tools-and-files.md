# Tools and Files

``` r

library(deepagentsr)
```

Tools and files are the main working surface for a deep agent. User
tools give the model controlled access to R functions. Built-in file
tools give it a virtual workspace for notes, drafts, large results, and
transcripts.

## Custom R tools

[`deep_tool()`](https://example.com/deepagentsr/reference/deep_tool.md)
stores the R function, model-facing metadata, side-effect metadata,
interrupt policy, and argument schema. Argument schemas can be explicit,
but the package also infers safe generic schemas from function formals.

``` r

summarise_text <- deep_tool(
  function(text, uppercase = FALSE) {
    out <- paste("Summary:", substr(text, 1, 24))
    if (uppercase) toupper(out) else out
  },
  name = "summarise_text",
  description = "Summarise a short text snippet.",
  side_effects = "none",
  returns = "text"
)

names(summarise_text$arguments)
#> [1] "text"      "uppercase"
summarise_text$fun("deepagentsr wraps tools and state", uppercase = TRUE)
#> [1] "SUMMARY: DEEPAGENTSR WRAPS TOOLS "
```

When the model is an `ellmer` chat object, the agent registers proxy
tools that preserve the original R function formals. Tool calls still
flow through the agent harness, so permissions, interrupts, events, and
offloading continue to work.

## Built-in filesystem tools

Every agent receives built-in tools for todos and virtual files:
`write_todos()`, `read_todos()`,
[`ls()`](https://rdrr.io/r/base/ls.html), `read_file()`, `write_file()`,
`edit_file()`, `glob()`, and
[`grep()`](https://rdrr.io/r/base/grep.html).

``` r

backend <- memory_backend()

file_agent <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call(
      "write_file",
      list(path = "/notes/a.txt", content = "alpha\nbeta\ngamma")
    ),
    assistant_tool_call("grep", list(pattern = "beta", path = "/notes")),
    assistant_message("I wrote and searched the note.")
  )),
  backend = backend
)

file_run <- file_agent$invoke("Create a note and search it.")
file_run$text
#> [1] "I wrote and searched the note."
backend$read("/notes/a.txt")
#> [1] "alpha\nbeta\ngamma"
backend$grep("beta", "/notes")
#>           path line_number line
#> 1 /notes/a.txt           2 beta
```

The default backend is in-memory and is ideal for tests, examples, and
ephemeral agent work.

``` r

mem <- memory_backend(list("/docs/readme.md" = "hello world"))
mem$write("/docs/changelog.md", "initial release")
mem$list("/docs")
#>                 path type size
#> 1 /docs/changelog.md file   15
#> 2    /docs/readme.md file   11
mem$glob("*.md", "/docs")
#> [1] "/docs/changelog.md" "/docs/readme.md"
```

## Filesystem and durable backends

[`filesystem_backend()`](https://example.com/deepagentsr/reference/filesystem_backend.md)
maps virtual paths into one configured host directory. It blocks path
traversal and common secret-like paths by default.

``` r

root <- tempfile("deepagentsr-fs-")
fs_backend <- filesystem_backend(root)

fs_backend$write("/reports/out.txt", "saved on disk")
fs_backend$read("/reports/out.txt")
#> [1] "saved on disk"
```

Use
[`rds_store_backend()`](https://example.com/deepagentsr/reference/rds_store_backend.md)
when you want a small durable virtual filesystem without exposing a host
directory tree to the agent.

``` r

store_path <- tempfile(fileext = ".rds")
store <- rds_store_backend(store_path)
store$write("/memory/fact.txt", "R has first-class functions.")

reopened <- rds_store_backend(store_path)
reopened$read("/memory/fact.txt")
#> [1] "R has first-class functions."
```

[`composite_backend()`](https://example.com/deepagentsr/reference/composite_backend.md)
can route path prefixes to different backends. This is useful when some
paths should be durable and others should remain temporary.

``` r

scratch <- memory_backend()
durable <- rds_store_backend(tempfile(fileext = ".rds"))
combined <- composite_backend(
  default = scratch,
  routes = list("/memory" = durable)
)

combined$write("/scratch.txt", "temporary")
combined$write("/memory/profile.txt", "durable")
combined$list("/", recursive = TRUE)
#>           path type size
#> 1 /scratch.txt file    9
#> 2      /memory  dir   NA
```

## Context offloading and summarization

Large tool results are automatically written to the backend when they
exceed the configured `offload_tokens` threshold. The model receives a
short reference and can inspect the full value later with `read_file()`
or [`grep()`](https://rdrr.io/r/base/grep.html).

``` r

large_result <- deep_tool(
  function() paste(rep("large output", 60), collapse = "\n"),
  name = "large_result",
  description = "Return a large result."
)

offload_backend <- memory_backend()
offload_agent <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call("large_result", list()),
    assistant_message("The result was offloaded.")
  )),
  tools = list(large_result),
  backend = offload_backend,
  context_budget = context_budget(offload_tokens = 10)
)

offload_run <- offload_agent$invoke("Call the large tool.")
offload_run$text
#> [1] "The result was offloaded."
offload_backend$list("/internal/offloads", recursive = TRUE)
#>                                                                     path type
#> 1 /internal/offloads/2026-06-30/offload-20260630230856.439-acgf0lko.json file
#> 2  /internal/offloads/2026-06-30/offload-20260630230856.439-acgf0lko.txt file
#>   size
#> 1  255
#> 2  779
```

If `max_input_tokens` is set, old turns can be compacted into a summary
while the full transcript is preserved in `/internal/transcripts`.

``` r

summary_backend <- memory_backend()
summary_agent <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call(
      "write_file",
      list(path = "/a.txt", content = paste(rep("alpha", 80), collapse = " "))
    ),
    assistant_tool_call("read_file", list(path = "/a.txt")),
    assistant_message("done")
  )),
  backend = summary_backend,
  context_budget = context_budget(
    max_input_tokens = 80,
    summarize_at = 0.3,
    keep_recent = 0.25
  )
)

summary_run <- summary_agent$invoke("Create and read a large file.")
vapply(summary_run$state$turns, function(turn) turn$role, character(1))
#> [1] "summary"   "tool"      "assistant"
summary_backend$list("/internal/transcripts", recursive = TRUE)
#>                                                                                              path
#> 1 /internal/transcripts/thread-20260630230856.486-cphlbgrz/summary-20260630230856.488-lwtdsuvu.md
#>   type size
#> 1 file  581
```

## Checkpoints and event traces

[`rds_checkpointer()`](https://example.com/deepagentsr/reference/rds_checkpointer.md)
persists thread state after completed runs and interrupts.

``` r

checkpoint_path <- tempfile(fileext = ".rds")
checkpointer <- rds_checkpointer(checkpoint_path)

checkpoint_agent <- create_deep_agent(
  model = fake_chat(list(assistant_message("checkpointed"))),
  checkpointer = checkpointer
)

checkpoint_run <- checkpoint_agent$invoke("hello")
checkpointer$list_threads()
#> [1] "thread-20260630230856.538-q6rw5wkz"

restored <- create_deep_agent(
  model = fake_chat(list(assistant_message("unused"))),
  checkpointer = checkpointer
)
restored$load_state(checkpoint_run$thread_id)
restored$get_state(checkpoint_run$thread_id)$status
#> [1] "completed"
```

Export execution events to JSON Lines for audit logs or downstream
analysis.

``` r

trace_path <- tempfile(fileext = ".jsonl")
export_events_jsonl(checkpoint_agent, trace_path, thread_id = checkpoint_run$thread_id)

trace <- read_events_jsonl(trace_path)
length(trace)
#> [1] 3
vapply(trace, function(event) event$type, character(1))
#> [1] "agent_start"   "model_message" "agent_end"
```
