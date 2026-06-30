# Create a deep agent

Create a deep agent

## Usage

``` r
create_deep_agent(
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
  context_budget = NULL,
  debug = FALSE,
  name = NULL
)
```

## Arguments

- model:

  Optional chat object, chat factory, fake chat, or model spec.

- tools:

  List of
  [`deep_tool()`](https://hadimaster65555.github.io/rdeepagent/reference/deep_tool.md)
  objects.

- system_prompt:

  Additional supervisor instructions.

- middleware:

  Optional list of event callback functions. Each receives one event
  record.

- subagents:

  List of
  [`subagent()`](https://hadimaster65555.github.io/rdeepagent/reference/subagent.md)
  configurations.

- skills:

  Optional skill root directories.

- memory:

  Optional memory files.

- backend:

  Virtual filesystem backend.

- permissions:

  List of
  [`fs_permission()`](https://hadimaster65555.github.io/rdeepagent/reference/fs_permission.md)
  rules.

- interrupt_on:

  Named list of
  [`interrupt_config()`](https://hadimaster65555.github.io/rdeepagent/reference/interrupt_config.md)
  objects.

- context_schema:

  Optional context validator. Use a function accepting `context`, or a
  named list mapping required context fields to type names or predicate
  functions.

- checkpointer:

  Optional durable checkpointer, such as
  [`rds_checkpointer()`](https://hadimaster65555.github.io/rdeepagent/reference/rds_checkpointer.md).

- store:

  Optional durable storage backend reserved for integrations.

- max_steps:

  Maximum agent loop steps.

- context_budget:

  Context budget configuration.

- debug:

  Whether to print debug output.

- name:

  Agent name.

## Value

A `DeepAgent` R6 object.
