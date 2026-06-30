# Define an agent tool

Define an agent tool

## Usage

``` r
deep_tool(
  fun,
  name = NULL,
  description,
  arguments = list(),
  side_effects = c("none", "read", "write", "network", "execute"),
  returns = c("text", "json", "file", "image", "data"),
  interrupt = FALSE,
  timeout = NULL,
  max_output_tokens = 20000,
  tags = character()
)
```

## Arguments

- fun:

  R function implementing the tool.

- name:

  Tool name exposed to the model.

- description:

  Tool description.

- arguments:

  Optional argument schema, compatible with
  [`ellmer::tool()`](https://ellmer.tidyverse.org/reference/tool.html).
  Missing schemas are inferred from `fun` formals as generic JSON types.

- side_effects:

  Side-effect metadata.

- returns:

  Return type metadata.

- interrupt:

  Whether the tool should pause for approval before execution.

- timeout:

  Optional timeout metadata.

- max_output_tokens:

  Approximate output token threshold before offloading.

- tags:

  Optional tags.

## Value

A `deep_tool` object.
