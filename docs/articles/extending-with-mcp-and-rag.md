# Extending with MCP and RAG

``` r

library(deepagentsr)
```

MCP, retrieval, and UI integrations are optional. The core package
remains small, while helpers make it straightforward to attach external
tools and apps.

## MCP tools

[`mcp_tools()`](https://hadimaster65555.github.io/rdeepagent/reference/mcp_tools.md)
accepts already materialized
[`deep_tool()`](https://hadimaster65555.github.io/rdeepagent/reference/deep_tool.md)
objects, which is useful when another part of your application has
already connected to an MCP server or converted remote capabilities.

``` r

remote_echo <- deep_tool(
  function(text) paste("remote echo:", text),
  name = "remote_echo",
  description = "Echo text through a remote-style tool.",
  side_effects = "network",
  returns = "text"
)

tools <- mcp_tools(tools = list(remote_echo))
tools[[1]]$name
#> [1] "remote_echo"
tools[[1]]$fun("hello")
#> [1] "remote echo: hello"
```

When [mcptools](https://github.com/posit-dev/mcptools) is installed,
`mcp_tools(config = ...)` can read an MCP configuration and convert
returned `ellmer` tool definitions into `deepagentsr` tools. If
[mcptools](https://github.com/posit-dev/mcptools) or a config file is
unavailable, the helper returns an empty list so optional integration
code can degrade cleanly.

``` r

agent <- create_deep_agent(
  model = ellmer::chat_openai(model = "gpt-4.1"),
  tools = c(
    list(local_tool),
    mcp_tools(config = "~/.config/mcptools/config.json")
  )
)
```

## RAG tools

Use
[`rag_tool()`](https://hadimaster65555.github.io/rdeepagent/reference/rag_tool.md)
to wrap any R search function with signature `query` and `k`. The search
function can query a data frame, a database, a vector store, or an
external service.

``` r

documents <- data.frame(
  title = c("tools", "approval", "memory"),
  text = c(
    "Tools expose R functions to the model.",
    "Approval pauses side effects before they run.",
    "Memory files are loaded into the supervisor prompt."
  ),
  stringsAsFactors = FALSE
)

search_docs <- function(query, k = 5) {
  hits <- grepl(query, documents$text, ignore.case = TRUE)
  head(documents[hits, , drop = FALSE], k)
}

search_tool <- rag_tool(search_docs)
search_tool$fun("approval", 2)
#>      title                                          text
#> 2 approval Approval pauses side effects before they run.
```

[`rag_tools()`](https://hadimaster65555.github.io/rdeepagent/reference/rag_tools.md)
returns a list so it can be concatenated with other tool lists.

``` r

agent <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call("search_docs", list(query = "Memory", k = 2)),
    assistant_message("Memory files are prompt context.")
  )),
  tools = rag_tools(search_fun = search_docs)
)

agent$invoke("What are memory files?")$text
#> [1] "Memory files are prompt context."
```

If [ragnar](https://ragnar.tidyverse.org/) is installed, pass a Ragnar
store to `rag_tools(store = store)`. The resulting `search_docs` tool
calls
[`ragnar::ragnar_retrieve()`](https://ragnar.tidyverse.org/reference/ragnar_retrieve.html).

``` r

store <- ragnar::ragnar_store_create(embed = my_embedder)

agent <- create_deep_agent(
  model = ellmer::chat_openai(model = "gpt-4.1"),
  tools = rag_tools(store = store, top_k = 5)
)
```

## Shiny chat apps

The package keeps Shiny out of core imports, but ships a small example
app under `inst/examples/shinychat`. It uses
[`as_shinychat_stream()`](https://hadimaster65555.github.io/rdeepagent/reference/as_shinychat_stream.md)
as the stable adapter point between `DeepAgent` event streams and a
Shiny chat UI.

``` r

chat_agent <- create_deep_agent(
  model = fake_chat(list(assistant_message("hello from the agent")))
)

stream <- as_shinychat_stream(chat_agent$stream("hello"))
class(stream)
#> [1] "coro_generator_instance"
```

Run the included app from an installed package:

``` r

shiny::runApp(system.file("examples", "shinychat", package = "deepagentsr"))
```

The app uses OpenAI through [ellmer](https://ellmer.tidyverse.org) when
`OPENAI_API_KEY` is set and falls back to
[`fake_chat()`](https://hadimaster65555.github.io/rdeepagent/reference/fake_chat.md)
otherwise.

## Live OpenAI smoke tests

The repository includes a guarded live test path for OpenAI model smoke
tests. Keep those tests out of normal package checks and opt in only
when credentials and model access are available.

``` r

readRenviron(".env")
Sys.setenv(RUN_OPENAI_LIVE_TESTS = "true")
devtools::test(filter = "live-openai")
```

The smoke matrix exercises tool-calling through the same
[`deep_tool()`](https://hadimaster65555.github.io/rdeepagent/reference/deep_tool.md)
and `ellmer` adapter path used by regular agents, including GPT 4.1 and
GPT 5 family models when the account has access.
