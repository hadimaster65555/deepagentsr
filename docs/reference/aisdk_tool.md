# Wrap an aisdk Agent as a deepagentsr tool

Wrap an aisdk Agent as a deepagentsr tool

## Usage

``` r
aisdk_tool(
  agent,
  name = NULL,
  description = NULL,
  model = NULL,
  max_steps = 10
)
```

## Arguments

- agent:

  An [`aisdk::Agent`](https://rdrr.io/pkg/aisdk/man/agent.html)-like
  object with a `$run()` method.

- name:

  Tool name.

- description:

  Tool description.

- model:

  Optional model override passed to `$run()`.

- max_steps:

  Maximum aisdk agent steps.

## Value

A
[`deep_tool()`](https://example.com/deepagentsr/reference/deep_tool.md).
