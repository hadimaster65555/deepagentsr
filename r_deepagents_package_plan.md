# Plan to Build an R Package Similar to Deep Agents

Date: 2026-06-30
Working package name: `{deepagentsr}`

## 1. Executive summary

Build `{deepagentsr}`, an R-native, batteries-included agent harness inspired by LangChain's Deep Agents. The package should expose a simple entry point, `create_deep_agent()`, that returns a stateful R6 object capable of planning, calling R tools, managing a virtual filesystem, spawning subagents, loading skills and memory, pausing for human approval, and streaming execution events.

The recommended core R dependency is `{ellmer}`. It is the best foundation because it already provides multi-provider chat clients, stateful chat objects, tool/function calling, streaming, async calls, structured data extraction, and provider-specific support. The package should use `{ellmer}` as the LLM and tool-calling substrate while implementing the Deep-Agents-style harness itself.

`{aisdk}` is also highly relevant. It already has agentic features in R, including Agents, Tasks, Flows, multi-agent teams, automatic function-to-tool schema generation, stateful chat sessions, telemetry, hooks, MCP support, memory, and skills. Treat `{aisdk}` as an accelerator, reference design, and optional interop target, not the initial hard dependency, unless the goal is to build a thin DeepAgents-flavored wrapper around an existing R agent runtime.

Recommended dependency posture:

- Core import: `{ellmer}`.
- Runtime imports: `{R6}`, `{rlang}`, `{cli}`, `{glue}`, `{jsonlite}`, `{yaml}`, `{fs}`, `{withr}`, `{digest}`, `{coro}`.
- Async/streaming imports or suggests: `{later}`, `{promises}`.
- Local execution/sandbox development suggests: `{callr}`, `{processx}`.
- Optional integrations: `{mcptools}` for MCP, `{ragnar}` for RAG-backed retrieval tools, `{shinychat}` for UI, `{aisdk}` for interop and reference implementations.
- Development stack: `{usethis}`, `{devtools}`, `{roxygen2}`, `{testthat}`, `{pkgdown}`, and optionally `{httptest2}` or `{vcr}` for API fixtures.

## 2. What Deep Agents provides

LangChain's Deep Agents is an opinionated agent harness, not just a minimal agent loop. Its documented principles are: opinionated defaults for long-horizon tasks, extensibility, model agnosticism, and production readiness on top of LangGraph. Its feature set includes subagents, filesystem access, context management, shell access, persistent memory, human-in-the-loop approval, skills, tools, and MCP support.

The Deep Agents quickstart shows the core shape of the user experience: define a model, register tools such as web search, provide a system prompt, then call `create_deep_agent()` and `invoke()`. The built-in harness automatically plans with a `write_todos` tool, uses file tools to offload context, spawns subagents, and synthesizes the result.

For an R version, the essence to replicate is not LangGraph itself. It is the higher-level product contract:

```r
agent <- create_deep_agent(
  model = ellmer::chat_openai(model = "gpt-4.1"),
  tools = list(internet_search),
  system_prompt = "You are an expert research assistant."
)

result <- agent$invoke("Research LangGraph and write a summary.")
```

The package should feel native to R users while preserving the important Deep Agents concepts: batteries-included defaults, clear extension points, safe-by-default filesystem and shell behavior, and a composable architecture.

## 3. Product goals and non-goals

### Goals

1. Provide a single high-level API for long-running, multi-step agent tasks in R.
2. Work with multiple LLM providers through `{ellmer}` rather than maintaining provider clients directly.
3. Make R functions usable as model-callable tools with rich metadata and policy controls.
4. Include built-in harness tools for planning, filesystem access, context offloading, subagent delegation, and human approval.
5. Support short-term state per thread and longer-term memory via backend routes.
6. Keep context small through offloading, summarization, and subagent isolation.
7. Make the package testable without live LLM calls by using fake models and deterministic tool loops.
8. Make unsafe capabilities opt-in: local shell execution, writes outside a sandbox root, networked tools, and destructive operations.

### Non-goals for the first version

1. Do not clone LangGraph in R. Implement a simpler R-native runtime first.
2. Do not depend on Python or reticulate for core functionality.
3. Do not hard-code OpenAI or any single provider.
4. Do not expose host shell execution by default.
5. Do not make `{aisdk}` a hard dependency unless the project intentionally becomes a wrapper or extension around `{aisdk}`.
6. Do not promise secure sandboxing from `callr` or `processx`; treat them as local development conveniences only.

## 4. Suitable R packages to use

### 4.1 Primary recommendation: `{ellmer}`

Use `{ellmer}` as the core LLM interface. It has the right abstraction level for building a DeepAgents-like harness: it handles provider diversity, model chat sessions, tools, streaming, async behavior, token and cost reporting, and structured outputs.

Why it fits:

- It supports many model providers, including OpenAI, Anthropic, Azure OpenAI, Gemini/Vertex, AWS Bedrock, Databricks, DeepSeek, Groq, Hugging Face, Mistral, Ollama, OpenRouter, Perplexity, Snowflake, and vLLM.
- Its `Chat` object is an R6 object that manages chat state and a tool loop.
- Its `tool()` function turns R functions into model-callable tools with argument schemas.
- It supports streaming and async APIs using generators/promises.
- It is on CRAN and actively documented by Posit/tidyverse maintainers.

How to use it:

- Accept either an existing `{ellmer}` chat object or a model specification that resolves to an `{ellmer}` chat object.
- Register user tools and built-in harness tools with `chat$register_tool()` or `chat$register_tools()`.
- Use `chat$stream()` and `chat$stream_async()` as the substrate for agent streaming.
- Clone or recreate chat objects for subagents so each subagent has an isolated context window.
- Use `chat$get_turns()`, `chat$set_turns()`, `chat$get_tokens()`, and `chat$get_cost()` for state inspection and observability.

### 4.2 Strong accelerator or reference: `{aisdk}`

`{aisdk}` is worth studying closely because it already overlaps with many DeepAgents concepts: multi-agent orchestration, tool systems, stateful chat sessions, hooks, MCP support, memory, and skills. It may also provide reusable ideas for agent/session boundaries.

Use it in one of three ways:

1. Reference only: borrow design patterns, especially the split between stateless agents and stateful sessions.
2. Optional interop: allow an `{aisdk}` Agent to be wrapped as a `{deepagentsr}` subagent or tool.
3. Alternative backend: if speed matters more than owning the agent runtime, build `{deepagentsr}` as a narrower API layer over `{aisdk}`.

Recommendation: begin with reference plus optional interop. Avoid a hard dependency at first because `{aisdk}` already owns many high-level agent concepts, which could blur the identity of the new package.

### 4.3 MCP: `{mcptools}`

Use `{mcptools}` as an optional integration so an R deep agent can consume third-party MCP tools and, eventually, serve R functions as MCP tools. This maps directly to Deep Agents' MCP support.

Design:

```r
agent <- create_deep_agent(
  model = ellmer::chat_openai(),
  tools = list(),
  mcp = list(
    github = mcp_server_stdio("github", command = "npx", args = c("..."))
  )
)
```

Internally, provide `mcp_tools()` helpers that return `{ellmer}`-compatible tool definitions when `{mcptools}` is installed.

### 4.4 Retrieval and long-term knowledge: `{ragnar}`

Use `{ragnar}` as an optional integration for document processing, chunking, embeddings, storage, and retrieval. This is not required for the core agent harness, but it is useful for building agent tools such as `search_docs()`, `search_memory()`, and project/document RAG.

### 4.5 UI: `{shinychat}`

Use `{shinychat}` only for optional demos and applications. The core package should remain UI-free, but a vignette can show how to connect a `DeepAgent` event stream to a Shiny chat UI.

### 4.6 Existing R agent packages to study

- `{LLMAgentR}`: graph-based agents and data-analysis workflows. Useful as a reference for R workflows, but it has a broad analytics-oriented dependency set and is less directly aligned with the DeepAgents harness concept.
- `{langchainr}`: potentially useful for comparison, but a new R-native package should not depend on a small wrapper around Python LangChain for its core.

## 5. Feature parity plan

| Deep Agents capability | R package design | MVP? | R packages to use |
| --- | --- | --- | --- |
| `create_deep_agent()` | `create_deep_agent()` returning an R6 `DeepAgent` | Yes | R6, ellmer |
| Model-agnostic chat | Accept `{ellmer}` `Chat` or model spec | Yes | ellmer |
| Custom tools | `deep_tool()` wrapper around `ellmer::tool()` plus policy metadata | Yes | ellmer, jsonlite |
| Built-in planning | `write_todos()` and `read_todos()` harness tools | Yes | internal |
| Filesystem tools | `ls`, `read_file`, `write_file`, `edit_file`, `glob`, `grep` over backend | Yes | fs, stringr/grep |
| Virtual filesystem backends | Memory, local filesystem, composite routes | Yes | fs, R6 |
| Context offloading | Store large tool inputs/results to VFS and replace with references | Yes | internal |
| Summarization | Summarize old turns when context threshold is reached | Yes, simple | ellmer |
| Subagents | `task()` tool routes to named subagent configs | Yes | ellmer, R6 |
| Default general-purpose subagent | Auto-add one unless disabled | Yes | internal |
| Skills | Scan `SKILL.md` frontmatter; load full skill on demand | Yes | yaml, fs |
| Memory | Always-load `AGENTS.md`/memory files; writable via VFS if permitted | Yes | fs, yaml |
| Human-in-the-loop | Interrupt object, approve/edit/reject/respond decisions, resume | Yes | internal, later Shiny |
| Permissions | Declarative allow/deny/interrupt path rules | Yes | internal, fs |
| MCP tools | Register MCP server tools | Optional MVP | mcptools |
| Shell/sandbox execution | Local dev backend first; real sandbox integration later | No for safe MVP | callr/processx optional |
| Streaming | Event stream for tokens, tool calls, subagents, state updates | Yes | ellmer, coro, promises |
| Observability | JSONL trace, event objects, token/cost summaries | Yes | jsonlite, cli, optional otel |
| RAG tools | `rag_tool()` for document search | Later | ragnar |

## 6. Proposed package architecture

### 6.1 Top-level API

```r
create_deep_agent <- function(
  model = NULL,
  tools = list(),
  system_prompt = NULL,
  middleware = list(),
  subagents = list(),
  skills = NULL,
  memory = NULL,
  backend = memory_backend(),
  permissions = list(),
  interrupt_on = list(),
  context_schema = NULL,
  checkpointer = NULL,
  store = NULL,
  max_steps = 30,
  context_budget = context_budget(),
  debug = FALSE,
  name = NULL
) {
  # validates config and returns DeepAgent$new(...)
}
```

The returned `DeepAgent` should expose:

```r
agent$invoke(input, thread_id = NULL, context = list(), files = list())
agent$stream(input, thread_id = NULL, context = list(), files = list())
agent$resume(thread_id, decisions)
agent$get_state(thread_id = NULL)
agent$get_events(thread_id = NULL)
agent$get_files(path = "/", thread_id = NULL)
agent$register_tool(tool)
agent$register_subagent(subagent)
agent$clone(deep = TRUE)
```

### 6.2 Core classes and records

Use R6 for stateful runtime objects and S3/S7-style simple records for configuration.

Core R6 classes:

- `DeepAgent`: supervisor agent runtime.
- `AgentThread`: per-thread mutable state, including turns, todos, files, summaries, pending interrupts, and events.
- `ToolRegistry`: stores built-in, custom, MCP, and subagent tools.
- `Backend`: virtual filesystem interface.
- `CompositeBackend`: routes path prefixes to other backends.
- `ContextManager`: handles offloading and summarization.
- `SubagentManager`: owns subagent configs and `task()` dispatch.
- `PermissionEngine`: evaluates read/write/execute rules.
- `EventEmitter`: stores and streams typed events.

Simple record constructors:

```r
subagent(name, description, system_prompt, tools = NULL, model = NULL,
         skills = NULL, max_steps = 10)

fs_permission(operations, paths, mode = c("allow", "deny", "interrupt"))

context_budget(max_input_tokens = NULL, offload_tokens = 20000,
               summarize_at = 0.85, keep_recent = 0.10)

interrupt_config(allowed_decisions = c("approve", "edit", "reject", "respond"),
                 when = NULL)
```

### 6.3 Model adapter layer

The package should not implement direct provider clients. Instead:

1. Users can pass an `{ellmer}` `Chat` object directly.
2. Users can pass a function that creates a `Chat` object.
3. Convenience helpers can map a small set of strings to `{ellmer}` constructors, for example `"openai:gpt-4.1"` or `"anthropic:claude-sonnet-4"`, but these helpers should be thin and clearly documented.

Subagents need isolated context. Because `{ellmer}` `Chat` objects are stateful, do not reuse the supervisor chat history for subagents. Either clone a provider/model configuration into a fresh chat object or require a model factory function.

Suggested internal abstraction:

```r
as_chat_factory <- function(model) {
  if (inherits(model, "Chat")) {
    return(function(system_prompt = NULL) {
      chat <- model$clone(deep = TRUE)
      if (!is.null(system_prompt)) chat$set_system_prompt(system_prompt)
      chat
    })
  }
  if (is.function(model)) return(model)
  abort("`model` must be an ellmer Chat object, a chat factory, or a supported model spec.")
}
```

### 6.4 Tool layer

Wrap `{ellmer::tool()}` so each tool carries additional agent metadata:

```r
deep_tool <- function(fun, name = NULL, description, arguments = list(),
                      side_effects = c("none", "read", "write", "network", "execute"),
                      returns = c("text", "json", "file", "image", "data"),
                      interrupt = FALSE,
                      timeout = NULL,
                      max_output_tokens = 20000,
                      tags = character()) {
  # returns a DeepTool object containing ellmer ToolDef + policy metadata
}
```

Tool execution pipeline:

1. Model requests a tool call through `{ellmer}`.
2. `ToolRegistry` finds metadata for the requested tool.
3. `PermissionEngine` checks policy.
4. HITL middleware may pause before execution.
5. Tool executes with timeout and error handling.
6. `ContextManager` offloads large outputs to backend.
7. Event emitter records request, result, duration, and output reference.
8. Tool result returns to the model.

Built-in harness tools:

- `write_todos(items)`: update the agent's task list.
- `read_todos()`: return current task list.
- `ls(path)`: list files from backend.
- `read_file(path, start_line = NULL, end_line = NULL)`: read file contents, possibly partial.
- `write_file(path, content, overwrite = TRUE)`: write content to backend.
- `edit_file(path, search, replace, occurrence = "all")`: patch text files.
- `glob(pattern, path = "/")`: match files.
- `grep(pattern, path = "/", ignore_case = FALSE)`: search files.
- `task(description, subagent = NULL, context = list())`: delegate to a subagent.
- `ask_user(question, options = NULL)`: request human input.
- Optional later: `execute(command, args = character(), timeout = 30)`: shell execution in sandbox backend only.

### 6.5 Virtual filesystem and backends

Define a backend protocol with methods:

```r
Backend$exists(path)
Backend$list(path, recursive = FALSE)
Backend$read(path, binary = FALSE)
Backend$write(path, content, overwrite = TRUE, binary = FALSE)
Backend$edit(path, search, replace, occurrence = "all")
Backend$glob(pattern, path = "/")
Backend$grep(pattern, path = "/", ignore_case = FALSE)
Backend$delete(path)
Backend$stat(path)
```

Implement these backends first:

1. `memory_backend()`: stores files in an environment/list. This is the default safe backend.
2. `filesystem_backend(root_dir, virtual_mode = TRUE)`: maps virtual paths to a local root. It must block `..`, `~`, absolute host paths outside root, symlink escapes, and hidden secret files by default.
3. `composite_backend(default, routes)`: routes prefixes such as `/workspace/`, `/memories/`, `/skills/`, and `/internal/` to different backends.
4. `rds_store_backend(path)`: durable state store for local development.

Default route pattern:

```r
backend <- composite_backend(
  default = memory_backend(),
  routes = list(
    "/workspace/" = filesystem_backend("./agent-workspace", virtual_mode = TRUE),
    "/memories/" = rds_store_backend("./.deepagentsr/memories.rds"),
    "/skills/" = filesystem_backend("./skills", virtual_mode = TRUE),
    "/internal/" = memory_backend()
  )
)
```

### 6.6 Context management

Implement two mechanisms from the beginning.

#### Offloading

If a tool input or output exceeds `context_budget$offload_tokens`, store it in the backend and return a compact reference:

```text
Large tool result offloaded to /internal/offloads/2026-06-30/<id>.json.
Preview:
1: ...
2: ...
Use read_file() or grep() to inspect the full result.
```

Store metadata next to the file:

```json
{
  "id": "...",
  "tool": "internet_search",
  "kind": "tool_result",
  "created_at": "2026-06-30T00:00:00Z",
  "approx_tokens": 35000,
  "content_path": "/internal/offloads/.../result.json"
}
```

#### Summarization

When the estimated prompt size exceeds the configured context budget:

1. Keep the recent turns.
2. Write a canonical transcript to `/internal/transcripts/<thread_id>/<summary_id>.md`.
3. Ask the model to produce a structured summary containing user goal, decisions, artifacts, tool results referenced by path, unresolved issues, and next steps.
4. Replace older turns in active memory with the summary plus file references.

Token estimation:

- Use provider token usage from `{ellmer}` when available after model calls.
- Use a configurable fallback: `ceil(nchar(text, type = "chars") / 4)`.
- Allow users to override with `token_estimator = function(text) ...`.

### 6.7 Subagents

Subagents should be first-class, not just tools. The supervisor gets a `task()` tool. When called, it creates an isolated subagent run and returns only the subagent's final report to the supervisor.

Subagent config:

```r
researcher <- subagent(
  name = "researcher",
  description = "Researches web and document sources and returns concise cited findings.",
  system_prompt = "You are a careful research subagent. Return only findings, citations, and uncertainties.",
  tools = list(internet_search, read_file, grep),
  max_steps = 12
)
```

Default behavior:

- Add a `general-purpose` subagent unless disabled.
- Let custom subagents override the default if they use the same name.
- Keep subagent toolsets minimal.
- Give every subagent a fresh chat context and thread-local state, but share the backend so useful artifacts can persist.
- Return concise results by default. Raw data should be written to files, then referenced.

### 6.8 Skills

Use the Agent Skills convention: a skill is a directory containing `SKILL.md` with YAML frontmatter. The package should scan skills at startup, inject only `name` and `description` into the system prompt, and let the agent read the full skill file on demand.

Skill directory:

```text
skills/
  r-package-development/
    SKILL.md
    references/
      cran-checklist.md
      testing-patterns.md
    scripts/
      run-check.R
    assets/
      DESCRIPTION-template
```

Skill loading algorithm:

1. Read configured skill roots.
2. Find child directories with `SKILL.md`.
3. Parse YAML frontmatter with `{yaml}`.
4. Validate required fields: `name`, `description`.
5. Add a compact skill inventory to the system prompt.
6. Provide a built-in `read_skill(name)` tool or instruct the model to call `read_file()` for the relevant `SKILL.md`.
7. Keep supporting resources on the backend until the skill instructions require them.

### 6.9 Memory

Memory differs from skills:

- Memory is always loaded into the system prompt.
- Skills are loaded progressively.

Support memory files such as:

```text
/memories/AGENTS.md
/memories/users/<user_id>/preferences.md
/memories/projects/<project_id>/conventions.md
```

Memory modes:

- Read-only memory: useful for organization policies and project rules.
- Writable memory: agent can update with `edit_file()` if permissions allow it.
- User-scoped memory: route namespace by `context$user_id`.
- Agent-scoped memory: route namespace by `agent$name`.

Default memory policy:

- Load memory files if configured.
- Make `/memories/**` read-only unless the user explicitly allows writes.
- Require human approval for writes to shared memory.

### 6.10 Human-in-the-loop and permissions

Implement two related but distinct mechanisms.

#### Tool interrupts

The user can configure tool calls that require review:

```r
agent <- create_deep_agent(
  model = chat,
  tools = list(send_email, delete_file),
  interrupt_on = list(
    send_email = interrupt_config(c("approve", "edit", "reject")),
    delete_file = interrupt_config(c("approve", "reject"))
  )
)
```

When interrupted, `agent$invoke()` returns an object such as:

```r
list(
  status = "interrupted",
  thread_id = "...",
  pending = list(
    tool = "send_email",
    arguments = list(to = "...", subject = "...", body = "..."),
    allowed_decisions = c("approve", "edit", "reject")
  )
)
```

Resume:

```r
agent$resume(thread_id, decision_approve())
agent$resume(thread_id, decision_edit(arguments = list(to = "fixed@example.com")))
agent$resume(thread_id, decision_reject(message = "Do not email external recipients."))
```

#### Filesystem permissions

Path rules should apply to built-in filesystem tools:

```r
permissions <- list(
  fs_permission("write", "/memories/**", "interrupt"),
  fs_permission("write", "/secrets/**", "deny"),
  fs_permission("read", "/secrets/**", "deny"),
  fs_permission(c("read", "write"), "/workspace/**", "allow")
)
```

Rules should be evaluated first-match-wins, with a documented default. Use a safe default for local filesystem backends: deny host paths outside the configured root.

### 6.11 Sandboxes and code execution

Do not include shell execution in the default agent. Add `execute()` only when the backend explicitly supports an execution interface.

MVP options:

1. No shell execution in the default release.
2. `local_dev_shell_backend()` behind a strong warning. Use `{callr}` or `{processx}` with a configured working directory, timeout, environment allowlist, and output limits. Document clearly that this is not a security sandbox.
3. Future real sandbox integrations: Docker, Kubernetes jobs, E2B, Daytona, Modal, or a remote internal execution service.

Security defaults:

- No inherited environment variables unless explicitly allowlisted.
- No write access outside root.
- No network unless explicitly allowed by backend/tool policy.
- Require approval for package installation, shell commands, git pushes, deletion, credential access, and outbound network operations.

### 6.12 Streaming and events

Expose a typed event stream rather than raw text only.

Event types:

- `agent_start`
- `agent_end`
- `model_token`
- `model_message`
- `tool_request`
- `tool_result`
- `tool_error`
- `file_write`
- `file_read`
- `todo_update`
- `subagent_start`
- `subagent_event`
- `subagent_end`
- `context_offload`
- `context_summary`
- `interrupt_pending`
- `interrupt_resolved`

R interface:

```r
stream <- agent$stream("Research R package development tools.")
coro::loop(for (event in stream) {
  print(event)
})
```

For Shiny, provide an adapter:

```r
as_shinychat_stream(agent$stream(...))
```

### 6.13 Observability

Add lightweight observability before adding production integrations.

Minimum:

- Store events in memory per thread.
- Export events to JSONL.
- Include token and cost summaries from `{ellmer}` when available.
- Record tool duration, errors, retries, and output offload paths.
- Include debug printing via `{cli}`.

Later:

- OpenTelemetry support through `{otel}` if the R ecosystem supports the required trace shape.
- A `pkgdown` article showing trace inspection.
- Optional event UI with `{shinychat}`.

## 7. Public API sketch

### 7.1 Quickstart example

```r
library(deepagentsr)
library(ellmer)

internet_search <- deep_tool(
  fun = function(query, max_results = 5) {
    # Implementation can call an R search package, an internal API, or MCP.
    data.frame(
      title = character(),
      url = character(),
      snippet = character()
    )
  },
  name = "internet_search",
  description = "Search the web for current information. Use for factual questions that require fresh sources.",
  arguments = list(
    query = ellmer::type_string("Search query"),
    max_results = ellmer::type_integer("Maximum number of results")
  ),
  side_effects = "network"
)

agent <- create_deep_agent(
  model = ellmer::chat_openai(model = "gpt-4.1"),
  tools = list(internet_search),
  system_prompt = paste(
    "You are an expert research assistant.",
    "Plan before acting. Write substantial intermediate results to files.",
    "Return concise answers with sources."
  ),
  backend = memory_backend(),
  permissions = list(
    fs_permission("write", "/memories/**", "interrupt")
  )
)

result <- agent$invoke("Research the R package ellmer and summarize why it is useful.")
cat(result$text)
```

### 7.2 Subagent example

```r
researcher <- subagent(
  name = "researcher",
  description = "Does careful web and document research, then returns concise sourced findings.",
  system_prompt = "Use tools to gather evidence. Return only conclusions, citations, and uncertainty notes.",
  tools = list(internet_search),
  max_steps = 10
)

writer <- subagent(
  name = "writer",
  description = "Turns findings into polished prose, preserving citations and uncertainty notes.",
  system_prompt = "Write clear, concise Markdown. Do not invent sources.",
  tools = list(),
  max_steps = 6
)

agent <- create_deep_agent(
  model = ellmer::chat_anthropic(),
  subagents = list(researcher, writer),
  system_prompt = "Coordinate subagents and produce final reports."
)
```

### 7.3 Skills example

```r
agent <- create_deep_agent(
  model = ellmer::chat_openai(),
  skills = "skills/",
  memory = c("/memories/AGENTS.md"),
  backend = composite_backend(
    default = memory_backend(),
    routes = list(
      "/skills/" = filesystem_backend("./skills", virtual_mode = TRUE),
      "/memories/" = rds_store_backend("./.deepagentsr/memory.rds")
    )
  )
)
```

### 7.4 Human approval example

```r
send_email <- deep_tool(
  function(to, subject, body) {
    # send email here
    "sent"
  },
  name = "send_email",
  description = "Send an email. Requires human approval.",
  arguments = list(
    to = ellmer::type_string("Recipient email address"),
    subject = ellmer::type_string("Email subject"),
    body = ellmer::type_string("Email body")
  ),
  side_effects = "network",
  interrupt = TRUE
)

agent <- create_deep_agent(
  model = ellmer::chat_openai(),
  tools = list(send_email),
  interrupt_on = list(send_email = interrupt_config(c("approve", "edit", "reject")))
)

run <- agent$invoke("Email Pat a summary of our findings.")

if (run$status == "interrupted") {
  run <- agent$resume(run$thread_id, decision_edit(
    arguments = list(subject = paste("Draft:", run$pending$arguments$subject))
  ))
}
```

## 8. Package structure

```text
deepagentsr/
  DESCRIPTION
  NAMESPACE
  R/
    agent.R
    create-deep-agent.R
    model-ellmer.R
    tools.R
    tool-registry.R
    builtin-tools-planning.R
    builtin-tools-files.R
    builtin-tools-subagents.R
    builtin-tools-hitl.R
    backend.R
    backend-memory.R
    backend-filesystem.R
    backend-composite.R
    backend-rds-store.R
    context-manager.R
    permissions.R
    hitl.R
    subagents.R
    skills.R
    memory.R
    events.R
    streaming.R
    observability.R
    mcp.R
    rag.R
    utils-paths.R
    utils-json.R
    utils-token-estimation.R
  inst/
    prompts/
      base-system-prompt.md
      planning-prompt.md
      filesystem-prompt.md
      subagent-prompt.md
      skills-prompt.md
      memory-prompt.md
      hitl-prompt.md
    examples/
      skills/
        r-package-development/
          SKILL.md
  tests/
    testthat/
      helper-fake-model.R
      test-tools.R
      test-backend-memory.R
      test-backend-filesystem.R
      test-permissions.R
      test-context-offloading.R
      test-subagents.R
      test-skills.R
      test-hitl.R
      test-events.R
  vignettes/
    quickstart.Rmd
    tools-and-files.Rmd
    subagents-skills-memory.Rmd
    safety-and-human-approval.Rmd
    extending-with-mcp-and-rag.Rmd
  man/
  README.Rmd
  _pkgdown.yml
```

## 9. Implementation roadmap

### Phase 0: Package skeleton and developer workflow

Deliverables:

- Create package with `{usethis}`.
- Add MIT or Apache-2.0 license after checking project policy.
- Configure `{roxygen2}`, `{testthat}`, `{pkgdown}`, GitHub Actions, linting, and examples.
- Add a fake model/test chat implementation so tests do not require paid LLM calls.

Acceptance criteria:

- `devtools::check()` passes locally.
- CI runs unit tests without API keys.
- README contains the target API and a non-live quickstart.

### Phase 1: `{ellmer}` model and tool integration

Deliverables:

- Implement `as_chat_factory()`.
- Implement `deep_tool()` and `ToolRegistry`.
- Implement registration of user tools into `{ellmer}` chat objects.
- Add tool metadata for side effects, output limits, and interrupt defaults.

Acceptance criteria:

- A simple calculator tool can be called by an `{ellmer}` chat object.
- Fake model tests can simulate tool requests and tool results deterministically.
- Tool errors return structured, model-readable messages.

### Phase 2: Backends and filesystem tools

Deliverables:

- Implement `Backend` protocol.
- Implement `memory_backend()`.
- Implement `filesystem_backend(root_dir, virtual_mode = TRUE)`.
- Implement `composite_backend()`.
- Implement built-in file tools.
- Add path traversal, symlink escape, and permission tests.

Acceptance criteria:

- `read_file()`, `write_file()`, `edit_file()`, `glob()`, and `grep()` work on memory and filesystem backends.
- Attempts to access `..`, host absolute paths, or paths outside root fail.
- All built-in file tools emit events.

### Phase 3: Agent runtime and planning

Deliverables:

- Implement `DeepAgent` R6 class.
- Implement `AgentThread` state.
- Add `write_todos()` and `read_todos()` planning tools.
- Assemble system prompt from custom prompt plus built-in harness prompts.
- Implement `invoke()` with max step limits, tool loop support, event capture, and errors.

Acceptance criteria:

- Agent can plan with todos, call a user tool, write an intermediate file, and return a final answer.
- `max_steps` prevents infinite loops.
- State can be retrieved after a run.

### Phase 4: Context offloading and summarization

Deliverables:

- Implement approximate token estimation.
- Implement offloading for large tool inputs and outputs.
- Implement transcript preservation.
- Implement summary compaction with configurable thresholds.

Acceptance criteria:

- Large tool output is written to `/internal/offloads/` and replaced with a reference plus preview.
- Agent can read back offloaded content through file tools.
- Summary compaction reduces active turns while preserving a transcript file.

### Phase 5: Subagents

Deliverables:

- Implement `subagent()` config.
- Implement default `general-purpose` subagent.
- Implement `SubagentManager` and built-in `task()` tool.
- Add subagent-specific event namespaces.
- Ensure subagents have fresh chat contexts but shared backend access.

Acceptance criteria:

- Supervisor can delegate to a named subagent and receive a concise final report.
- Subagent intermediate tool calls do not bloat supervisor context.
- Events show main-agent versus subagent execution.

### Phase 6: Skills and memory

Deliverables:

- Implement skill discovery from `SKILL.md` frontmatter.
- Add skill inventory to system prompt.
- Implement helper tools or prompt guidance for loading full skills.
- Implement always-loaded memory files.
- Add read-only and writable memory permission examples.

Acceptance criteria:

- Skills load at startup as compact metadata.
- Agent can read full `SKILL.md` when relevant.
- Memory files appear in the assembled prompt.
- Writes to `/memories/**` can be denied or interrupted.

### Phase 7: Human-in-the-loop and permissions

Deliverables:

- Implement `interrupt_config()` and decision objects.
- Implement `agent$resume()`.
- Implement tool-level interrupts.
- Implement filesystem `allow`, `deny`, and `interrupt` rules.
- Add tests for decision order and edited arguments.

Acceptance criteria:

- Sensitive tool calls can pause before execution.
- Human can approve, edit, reject, or respond where allowed.
- Resume continues the same thread without corrupting history.

### Phase 8: Streaming and observability

Deliverables:

- Implement event stream with `{coro}`.
- Add sync and async streaming if feasible through `{ellmer}`.
- Add JSONL trace export.
- Add token/cost reporting from `{ellmer}`.
- Add debug printing with `{cli}`.

Acceptance criteria:

- User can stream tool requests, tool results, subagent events, and final text.
- JSONL traces can be loaded into a data frame.
- Token/cost summaries are exposed when the provider returns them.

### Phase 9: Optional integrations and public preview

Deliverables:

- `{mcptools}` integration for MCP servers.
- `{ragnar}` integration for document search tools.
- `{shinychat}` demo app.
- `{aisdk}` adapter proof of concept.
- `pkgdown` site with vignettes and reference docs.

Acceptance criteria:

- MCP tools can be registered when `{mcptools}` is installed.
- RAG search tool works with a `{ragnar}` store.
- Public examples run with mocked or low-cost models.
- `R CMD check` passes with optional integrations skipped when dependencies are unavailable.

## 10. Testing strategy

### 10.1 Unit tests without LLM calls

Create a fake chat/model that accepts scripted responses:

```r
fake <- fake_chat(list(
  assistant_tool_call("write_todos", list(items = list("Search", "Summarize"))),
  assistant_tool_call("internet_search", list(query = "ellmer R package")),
  assistant_message("Final answer")
))
```

Use it to test:

- Tool registration and execution.
- Permission handling.
- Context offloading.
- Summarization state transitions.
- Subagent delegation.
- HITL interruptions and resume.
- Event stream ordering.

### 10.2 Integration tests

Run only when API keys are present:

- One OpenAI or Anthropic smoke test through `{ellmer}`.
- One local Ollama smoke test if `OLLAMA_HOST` is present.
- One MCP smoke test if `{mcptools}` and test server are configured.
- One RAG smoke test if `{ragnar}` store exists.

### 10.3 Safety tests

Mandatory tests:

- Path traversal attempts fail.
- Symlink escapes fail.
- Hidden secret path patterns can be denied.
- Shell backend is disabled unless explicitly configured.
- Tool interrupts occur before side effects.
- Edited HITL arguments are validated before execution.
- Large outputs are truncated/offloaded before returning to the model.

### 10.4 Evaluation tasks

Create a small deterministic evaluation suite:

1. Research task: use mocked search results and produce a cited summary.
2. File task: create, edit, search, and summarize files.
3. Subagent task: delegate two subtasks and synthesize the result.
4. Skill task: load a skill and follow its workflow.
5. Memory task: read memory and avoid violating a stored preference.
6. HITL task: attempt email or file deletion and pause correctly.
7. Context task: handle a large mocked tool result without exceeding context.

## 11. Security model

Use the same core assumption as Deep Agents: the LLM can do anything its tools allow. Therefore, safety belongs in tool definitions, permissions, backends, sandboxing, and human approval, not in the model prompt alone.

Default security posture:

- No shell execution by default.
- Memory backend by default.
- Local filesystem access requires explicit root directory.
- Virtual filesystem mode is enabled by default.
- Writes to memory are denied or interrupted by default.
- Destructive and network side-effect tools should require explicit metadata.
- Tool output size limits are enforced.
- Human approval is available for sensitive tool calls.
- Secrets must not be placed in the agent workspace.

Documentation must clearly state:

- `filesystem_backend()` is a capability grant.
- `local_dev_shell_backend()` is not a security sandbox.
- Path permissions do not secure arbitrary custom tools unless those tools call the permission engine.
- MCP tools can carry external risks and need review.
- The model may attempt prompt injection; tools and backends must enforce boundaries.

## 12. Documentation plan

### README

Include:

- What `{deepagentsr}` is.
- Why it exists: DeepAgents-style workflow for R.
- Minimal quickstart.
- Safety note.
- Dependency recommendation: `{ellmer}` core, optional `{mcptools}`, `{ragnar}`, `{shinychat}`, `{aisdk}`.

### Vignettes

1. `quickstart.Rmd`: build a research agent.
2. `tools-and-files.Rmd`: define tools and use the virtual filesystem.
3. `subagents-skills-memory.Rmd`: delegate and load skill/memory files.
4. `safety-and-human-approval.Rmd`: permissions, interrupts, local filesystem risks.
5. `extending-with-mcp-and-rag.Rmd`: optional MCP and RAG integrations.

### Reference docs

Use roxygen examples that avoid live API calls by default. Put live API examples inside `donttest{}` or vignettes with environment checks.

## 13. CRAN and release strategy

CRAN-friendly choices:

- Keep core dependencies modest.
- Put heavy integrations in `Suggests`.
- Skip live API tests on CRAN.
- Avoid writing outside temporary directories in tests.
- Avoid shell execution tests on CRAN unless harmless and isolated.
- Provide examples that run without credentials or are guarded by `if (has_credentials())`.

Version milestones:

- `0.0.1`: internal skeleton, fake model, tool registry.
- `0.1.0`: MVP single-agent runtime, tools, memory backend, file tools, planning.
- `0.2.0`: subagents, context offloading, skills and memory.
- `0.3.0`: HITL, permissions, streaming, JSONL traces.
- `0.4.0`: MCP/RAG/UI optional integrations.
- `1.0.0`: stable API, complete safety docs, tested examples, CRAN-ready.

## 14. Key design decisions

### Decision 1: Use `{ellmer}` as the core dependency

Rationale: `{ellmer}` is provider-agnostic and handles the model/tool plumbing. This lets `{deepagentsr}` focus on the harness: planning, VFS, subagents, memory, skills, permissions, and context management.

### Decision 2: Treat `{aisdk}` as a reference and optional interop layer

Rationale: `{aisdk}` has relevant agent features, but a hard dependency could make `{deepagentsr}` a thin wrapper. Optional interop lets advanced users compose `{aisdk}` Agents into `{deepagentsr}` without forcing that architecture on the core.

### Decision 3: Implement a virtual filesystem before shell execution

Rationale: Filesystem tools are core to DeepAgents-style context management. Shell execution is riskier and can wait until sandbox boundaries are clear.

### Decision 4: Use R6 for stateful runtimes

Rationale: `{ellmer}` already uses R6 for mutable chat state, and agent runtimes naturally need mutable thread state, event streams, and registries.

### Decision 5: Make safety declarative

Rationale: A user should be able to audit tool side effects, filesystem permissions, and interrupt rules from configuration, rather than reading prompt text.

## 15. Main risks and mitigations

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Tool loop becomes unreliable | R tool calls can fail, return large objects, or produce ambiguous outputs | Strict schemas, JSON serialization, output previews, robust errors |
| Context grows too quickly | Long tasks accumulate turns and tool results | Offload large data, summarize old turns, use subagents |
| Filesystem access leaks secrets | Agents may read `.env` or credentials | Default memory backend, virtual root, deny patterns, docs, HITL |
| Shell execution is dangerous | `execute()` can modify host system or exfiltrate data | No shell by default, real sandbox integrations later |
| Subagents are overused | Delegation adds overhead and complexity | Clear descriptions, minimal tools, default max steps |
| Live API tests are flaky or expensive | CRAN and CI cannot rely on external providers | Fake model unit tests, optional integration tests |
| Dependency creep | Agent packages can become heavy quickly | Core imports only for required runtime; integrations in Suggests |
| `{ellmer}` API changes | The ecosystem is moving quickly | Pin minimum versions, adapter layer, compatibility tests |
| `{aisdk}` overlap creates confusion | Users may ask why both exist | Clear positioning: `{deepagentsr}` is a DeepAgents-style harness; `{aisdk}` is optional/reference |

## 16. First build checklist

1. Create package skeleton with `{usethis}`.
2. Add `DESCRIPTION` imports and suggests.
3. Implement fake chat/model for deterministic tests.
4. Implement `deep_tool()` and `ToolRegistry`.
5. Implement `memory_backend()` and file tools.
6. Implement `DeepAgent$invoke()` with planning tool.
7. Add context offload for large tool results.
8. Add default general-purpose subagent and `task()` tool.
9. Add skills metadata scanning.
10. Add memory file loading.
11. Add permissions and HITL interrupts.
12. Add `DeepAgent$stream()` and JSONL event export.
13. Write quickstart, safety, and extension vignettes.
14. Add CI and `pkgdown` site.
15. Run full check and review examples for CRAN safety.

## 17. Source notes

Deep Agents and LangChain sources:

- Deep Agents GitHub repository: https://github.com/langchain-ai/deepagents
- Deep Agents overview: https://docs.langchain.com/oss/python/deepagents/overview
- Deep Agents quickstart: https://docs.langchain.com/oss/python/deepagents/quickstart
- Deep Agents customization: https://docs.langchain.com/oss/python/deepagents/customization
- Deep Agents tools: https://docs.langchain.com/oss/python/deepagents/tools
- Deep Agents backends: https://docs.langchain.com/oss/python/deepagents/backends
- Deep Agents context engineering: https://docs.langchain.com/oss/python/deepagents/context-engineering
- Deep Agents subagents: https://docs.langchain.com/oss/python/deepagents/subagents
- Deep Agents human-in-the-loop: https://docs.langchain.com/oss/python/deepagents/human-in-the-loop
- Deep Agents permissions: https://docs.langchain.com/oss/python/deepagents/permissions
- Deep Agents skills: https://docs.langchain.com/oss/python/deepagents/skills
- Deep Agents streaming: https://docs.langchain.com/oss/python/deepagents/streaming
- Deep Agents sandboxes: https://docs.langchain.com/oss/python/deepagents/sandboxes

R package sources:

- `{ellmer}` site: https://ellmer.tidyverse.org/
- `{ellmer}` CRAN page: https://cran.r-project.org/package=ellmer
- `{ellmer}` tool/function calling: https://ellmer.tidyverse.org/articles/tool-calling.html
- `{ellmer}` Chat object: https://ellmer.tidyverse.org/reference/Chat.html
- `{ellmer}` tool reference: https://ellmer.tidyverse.org/reference/tool.html
- `{ellmer}` streaming and async APIs: https://ellmer.tidyverse.org/articles/streaming-async.html
- `{aisdk}` site: https://yulab-smu.top/aisdk/
- `{aisdk}` CRAN page: https://cran.r-project.org/package=aisdk
- `{aisdk}` README: https://cran.r-project.org/web/packages/aisdk/readme/README.html
- `{aisdk}` Agent class reference: https://rdrr.io/cran/aisdk/man/agent.html
- `{mcptools}` site: https://posit-dev.github.io/mcptools/
- `{mcptools}` CRAN page: https://cran.r-project.org/package=mcptools
- `{ragnar}` site: https://ragnar.tidyverse.org/
- `{ragnar}` CRAN page: https://cran.r-project.org/package=ragnar
- `{shinychat}` site: https://posit-dev.github.io/shinychat/r/index.html
- `{shinychat}` CRAN page: https://cran.r-project.org/package=shinychat
- `{LLMAgentR}` site: https://knowusuboaky.github.io/LLMAgentR/
- `{LLMAgentR}` CRAN page: https://cran.r-project.org/package=LLMAgentR

R package development sources:

- `{usethis}` site: https://usethis.r-lib.org/
- `{devtools}` site: https://devtools.r-lib.org/
- `{testthat}` site: https://testthat.r-lib.org/
- `{roxygen2}` repository: https://github.com/r-lib/roxygen2
- R package development cheat sheet: https://rstudio.github.io/cheatsheets/html/package-development.html
