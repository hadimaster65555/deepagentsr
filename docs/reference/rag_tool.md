# Create a retrieval tool from an R search function

Create a retrieval tool from an R search function

## Usage

``` r
rag_tool(
  search_fun,
  name = "search_docs",
  description = "Search a retrieval index for relevant documents."
)
```

## Arguments

- search_fun:

  Function with arguments `query` and `k`.

- name:

  Tool name.

- description:

  Tool description.

## Value

A
[`deep_tool()`](https://hadimaster65555.github.io/rdeepagent/reference/deep_tool.md).
