# Wrap an aisdk Agent as a direct deepagentsr subagent

Wrap an aisdk Agent as a direct deepagentsr subagent

## Usage

``` r
aisdk_subagent(
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

  Subagent name.

- description:

  Subagent description.

- model:

  Optional model override passed to `$run()`.

- max_steps:

  Maximum aisdk agent steps.

## Value

A [`subagent()`](https://example.com/deepagentsr/reference/subagent.md)
configuration.
