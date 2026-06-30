# Return optional RAG tools

Return optional RAG tools

## Usage

``` r
rag_tools(search_fun = NULL, store = NULL, top_k = 3L, ...)
```

## Arguments

- search_fun:

  Optional search function to wrap with
  [`rag_tool()`](https://hadimaster65555.github.io/deepagentsr/reference/rag_tool.md).

- store:

  Optional Ragnar store object or path.

- top_k:

  Default number of chunks to retrieve from a Ragnar store.

- ...:

  Additional arguments passed to
  [`rag_tool()`](https://hadimaster65555.github.io/deepagentsr/reference/rag_tool.md).

## Value

A list of tools.
