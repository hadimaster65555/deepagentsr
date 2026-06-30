# Safety and Human Approval

``` r

library(deepagentsr)
```

Agent tools can read files, write files, call APIs, or trigger other
side effects. `deepagentsr` keeps those capabilities explicit through
three layers:

- side-effect metadata on tools;
- filesystem permission rules;
- human-in-the-loop interrupts and resume decisions.

## Tool-level interrupts

Set `interrupt = TRUE` on a tool when every call should pause before the
function body runs.

``` r

sent <- new.env(parent = emptyenv())
sent$value <- FALSE

send_email <- deep_tool(
  function(to) {
    sent$value <- to
    "sent"
  },
  name = "send_email",
  description = "Send an email.",
  side_effects = "network",
  interrupt = TRUE
)

email_agent <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call("send_email", list(to = "a@example.com")),
    assistant_message("Email sent.")
  )),
  tools = list(send_email)
)

paused <- email_agent$invoke("Send the email.")
paused$status
#> [1] "interrupted"
paused$pending$tool
#> [1] "send_email"
sent$value
#> [1] FALSE
```

The side effect has not happened yet. Resume the same thread with one of
the decision helpers.

``` r

resumed <- email_agent$resume(
  paused$thread_id,
  decision_edit(list(to = "b@example.com"))
)

resumed$status
#> [1] "completed"
sent$value
#> [1] "b@example.com"
```

Use
[`decision_approve()`](https://hadimaster65555.github.io/rdeepagent/reference/decision_approve.md)
to run the original arguments,
[`decision_edit()`](https://hadimaster65555.github.io/rdeepagent/reference/decision_edit.md)
to replace arguments,
[`decision_reject()`](https://hadimaster65555.github.io/rdeepagent/reference/decision_reject.md)
to tell the model the call was rejected, or
[`decision_respond()`](https://hadimaster65555.github.io/rdeepagent/reference/decision_respond.md)
to provide a human answer without running the tool.

``` r

reject_agent <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call("send_email", list(to = "a@example.com")),
    assistant_message("I did not send the email.")
  )),
  tools = list(send_email)
)

rejected <- reject_agent$invoke("Send another email.")
reject_agent$resume(rejected$thread_id, decision_reject("Do not send email."))$text
#> [1] "I did not send the email."
```

## Filesystem permissions

[`fs_permission()`](https://hadimaster65555.github.io/rdeepagent/reference/fs_permission.md)
rules apply to built-in file tools. A rule can allow, deny, or interrupt
operations on matching virtual paths.

``` r

write_agent <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call(
      "write_file",
      list(path = "/reports/out.md", content = "draft")
    ),
    assistant_message("Report saved.")
  )),
  permissions = list(
    fs_permission("write", "/reports/out.md", mode = "interrupt")
  )
)

write_paused <- write_agent$invoke("Write the report.")
write_paused$status
#> [1] "interrupted"
write_paused$pending$kind
#> [1] "permission"

write_done <- write_agent$resume(write_paused$thread_id, decision_approve())
write_done$status
#> [1] "completed"
```

Denied file operations fail immediately.

``` r

blocked_agent <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call("read_file", list(path = "/secret.txt"))
  )),
  backend = memory_backend(list("/secret.txt" = "token")),
  permissions = list(
    fs_permission("read", "/secret.txt", mode = "deny")
  )
)

blocked <- try(blocked_agent$invoke("Read the secret."), silent = TRUE)
inherits(blocked, "try-error")
#> [1] TRUE
```

## Filesystem backend safety

[`filesystem_backend()`](https://hadimaster65555.github.io/rdeepagent/reference/filesystem_backend.md)
maps all virtual paths under one configured host directory. It blocks
path traversal and, by default, common secret-like paths such as
`/.env`.

``` r

root <- tempfile("deepagentsr-fs-")
safe_fs <- filesystem_backend(root)
safe_fs$write("/notes/a.txt", "safe")
safe_fs$read("/notes/a.txt")
#> [1] "safe"

secret_write <- try(safe_fs$write("/.env", "OPENAI_API_KEY=..."), silent = TRUE)
inherits(secret_write, "try-error")
#> [1] TRUE
```

## Local shell tool

Shell execution is not part of the default runtime.
[`local_dev_shell_tool()`](https://hadimaster65555.github.io/rdeepagent/reference/local_dev_shell_tool.md)
is an opt-in local development convenience, not a security sandbox.
Register it only for trusted tasks and restrict commands with
`allowed_commands`.

``` r

rscript <- file.path(R.home("bin"), "Rscript")
execute <- local_dev_shell_tool(
  root_dir = tempdir(),
  allowed_commands = rscript,
  timeout = 10
)

agent <- create_deep_agent(
  model = ellmer::chat_openai(model = "gpt-4.1"),
  tools = list(execute),
  interrupt_on = list(execute = interrupt_config())
)
```

## Auditing decisions

Interrupts, approvals, rejections, file reads, file writes, and tool
results are emitted as events. Export a thread trace when you need an
audit record.

``` r

trace_path <- tempfile(fileext = ".jsonl")
export_events_jsonl(write_agent, trace_path, thread_id = write_done$thread_id)

events <- read_events_jsonl(trace_path)
vapply(events, function(event) event$type, character(1))
#> [1] "agent_start"        "tool_request"       "interrupt_pending" 
#> [4] "interrupt_resolved" "tool_request"       "file_write"        
#> [7] "tool_result"        "model_message"      "agent_end"
```
