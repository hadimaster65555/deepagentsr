# Package index

## Agent runtime

- [`create_deep_agent()`](https://hadimaster65555.github.io/deepagentsr/reference/create_deep_agent.md)
  : Create a deep agent
- [`context_budget()`](https://hadimaster65555.github.io/deepagentsr/reference/context_budget.md)
  : Configure context budget behavior
- [`as_chat_factory()`](https://hadimaster65555.github.io/deepagentsr/reference/as_chat_factory.md)
  : Convert a model input to a chat factory
- [`deep_tool()`](https://hadimaster65555.github.io/deepagentsr/reference/deep_tool.md)
  : Define an agent tool
- [`as_ellmer_tool()`](https://hadimaster65555.github.io/deepagentsr/reference/as_ellmer_tool.md)
  : Convert a deep tool to an ellmer tool
- [`subagent()`](https://hadimaster65555.github.io/deepagentsr/reference/subagent.md)
  : Define a subagent

## Backends and safety

- [`memory_backend()`](https://hadimaster65555.github.io/deepagentsr/reference/memory_backend.md)
  : Create an in-memory virtual filesystem backend
- [`filesystem_backend()`](https://hadimaster65555.github.io/deepagentsr/reference/filesystem_backend.md)
  : Create a local filesystem backend
- [`composite_backend()`](https://hadimaster65555.github.io/deepagentsr/reference/composite_backend.md)
  : Create a composite virtual filesystem backend
- [`rds_store_backend()`](https://hadimaster65555.github.io/deepagentsr/reference/rds_store_backend.md)
  : Create a durable RDS-backed virtual filesystem backend
- [`rds_checkpointer()`](https://hadimaster65555.github.io/deepagentsr/reference/rds_checkpointer.md)
  : Create an RDS checkpointer
- [`fs_permission()`](https://hadimaster65555.github.io/deepagentsr/reference/fs_permission.md)
  : Create a filesystem permission rule
- [`interrupt_config()`](https://hadimaster65555.github.io/deepagentsr/reference/interrupt_config.md)
  : Configure a human-in-the-loop interrupt
- [`decision_approve()`](https://hadimaster65555.github.io/deepagentsr/reference/decision_approve.md)
  : Human approval decision
- [`decision_edit()`](https://hadimaster65555.github.io/deepagentsr/reference/decision_edit.md)
  : Human edit decision
- [`decision_reject()`](https://hadimaster65555.github.io/deepagentsr/reference/decision_reject.md)
  : Human rejection decision
- [`decision_respond()`](https://hadimaster65555.github.io/deepagentsr/reference/decision_respond.md)
  : Human response decision
- [`local_dev_shell_tool()`](https://hadimaster65555.github.io/deepagentsr/reference/local_dev_shell_tool.md)
  : Create an opt-in local development shell tool

## Extensions

- [`aisdk_tool()`](https://hadimaster65555.github.io/deepagentsr/reference/aisdk_tool.md)
  : Wrap an aisdk Agent as a deepagentsr tool
- [`aisdk_subagent()`](https://hadimaster65555.github.io/deepagentsr/reference/aisdk_subagent.md)
  : Wrap an aisdk Agent as a direct deepagentsr subagent
- [`discover_skills()`](https://hadimaster65555.github.io/deepagentsr/reference/discover_skills.md)
  : Discover skills from directories
- [`mcp_tools()`](https://hadimaster65555.github.io/deepagentsr/reference/mcp_tools.md)
  : Return optional MCP-backed tools
- [`rag_tool()`](https://hadimaster65555.github.io/deepagentsr/reference/rag_tool.md)
  : Create a retrieval tool from an R search function
- [`rag_tools()`](https://hadimaster65555.github.io/deepagentsr/reference/rag_tools.md)
  : Return optional RAG tools
- [`as_shinychat_stream()`](https://hadimaster65555.github.io/deepagentsr/reference/as_shinychat_stream.md)
  : Adapt an agent event stream for Shiny chat demos

## Events

- [`export_events_jsonl()`](https://hadimaster65555.github.io/deepagentsr/reference/export_events_jsonl.md)
  : Export agent events as JSON Lines
- [`read_events_jsonl()`](https://hadimaster65555.github.io/deepagentsr/reference/read_events_jsonl.md)
  : Read a JSON Lines event trace
- [`print(`*`<deepagent_event_stream>`*`)`](https://hadimaster65555.github.io/deepagentsr/reference/print.deepagent_event_stream.md)
  : Print an agent event stream

## Testing helpers

- [`fake_chat()`](https://hadimaster65555.github.io/deepagentsr/reference/fake_chat.md)
  : Create a deterministic fake chat model
- [`assistant_message()`](https://hadimaster65555.github.io/deepagentsr/reference/assistant_message.md)
  : Create a scripted assistant message
- [`assistant_tool_call()`](https://hadimaster65555.github.io/deepagentsr/reference/assistant_tool_call.md)
  : Create a scripted assistant tool call
