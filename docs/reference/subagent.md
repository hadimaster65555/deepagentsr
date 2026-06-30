# Define a subagent

Define a subagent

## Usage

``` r
subagent(
  name,
  description,
  system_prompt,
  tools = NULL,
  model = NULL,
  skills = NULL,
  max_steps = 10,
  runner = NULL
)
```

## Arguments

- name:

  Subagent name.

- description:

  Description used by the supervisor.

- system_prompt:

  Subagent system prompt.

- tools:

  Optional tool list.

- model:

  Optional model or chat factory. Defaults to the supervisor model.

- skills:

  Optional skills.

- max_steps:

  Maximum loop steps.

- runner:

  Optional function used to execute the subagent directly. It receives
  `task` and `context` arguments. This is primarily for interop wrappers
  such as
  [`aisdk_subagent()`](https://example.com/deepagentsr/reference/aisdk_subagent.md).

## Value

A subagent configuration.
