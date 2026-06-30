test_that("rag_tool wraps a retrieval function", {
  tool <- rag_tool(function(query, k = 5) data.frame(query = query, k = k))
  out <- tool$fun("alpha", 3)
  expect_equal(out$query, "alpha")
  expect_equal(out$k, 3)
})

test_that("mcp_tools accepts materialized deep tools and degrades without mcptools", {
  tool <- deep_tool(function() "ok", name = "ok", description = "OK")
  expect_equal(mcp_tools(tools = list(tool))[[1]]$name, "ok")
  expect_type(mcp_tools(), "list")
})

test_that("mcp_tools reads an mcptools config when available", {
  skip_if_not_installed("mcptools")
  config <- tempfile(fileext = ".json")
  file.create(config)
  expect_equal(mcp_tools(config = config), list())
})

test_that("ellmer ToolDef can be adapted to deep_tool for MCP clients", {
  skip_if_not_installed("ellmer")
  ellmer_tool <- ellmer::tool(
    function(x) paste("echo", x),
    name = "echo",
    description = "Echo text.",
    arguments = list(x = ellmer::type_string("Text"))
  )
  tool <- deepagentsr:::deep_tool_from_ellmer(ellmer_tool)
  expect_equal(tool$name, "echo")
  expect_equal(tool$fun("hi"), "echo hi")
})

test_that("rag_tools can wrap Ragnar store retrieval", {
  skip_if_not_installed("ragnar")
  store <- ragnar::ragnar_store_create(embed = NULL)
  doc <- ragnar::MarkdownDocument(
    "alpha beta gamma\nchocolate cake dessert",
    origin = "memory"
  )
  chunks <- ragnar::markdown_chunk(doc, target_size = 20)
  ragnar::ragnar_store_insert(store, chunks)
  ragnar::ragnar_store_build_index(store)

  tool <- rag_tools(store = store)[[1]]
  expect_equal(tool$name, "search_docs")
  expect_s3_class(tool, "deep_tool")
  results <- tool$fun("chocolate", 3)
  expect_true(any(grepl("chocolate", results$text)))
})

test_that("as_shinychat_stream returns stream extension point", {
  agent <- create_deep_agent(model = fake_chat(list(assistant_message("done"))))
  stream <- agent$stream("hello")
  expect_identical(as_shinychat_stream(stream), stream)
})

test_that("shinychat example app is shipped and syntactically valid", {
  app <- system.file("examples", "shinychat", "app.R", package = "deepagentsr")
  if (!nzchar(app)) {
    app <- file.path("inst", "examples", "shinychat", "app.R")
  }

  expect_true(file.exists(app))
  expect_silent(parse(app))
})
