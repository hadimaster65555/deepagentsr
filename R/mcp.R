#' Return optional MCP-backed tools
#'
#' @param config Optional mcptools MCP server configuration path.
#' @param tools Optional list of already materialized [deep_tool()] objects.
#' @param ... Reserved for future `{mcptools}` server configuration.
#' @return A list of tools.
#' @export
mcp_tools <- function(config = NULL, tools = list(), ...) {
  if (length(tools)) {
    if (!all(vapply(tools, inherits, logical(1), "deep_tool"))) {
      deep_abort("`tools` must be a list of deep_tool objects.")
    }
    return(tools)
  }
  if (!requireNamespace("mcptools", quietly = TRUE)) {
    return(list())
  }
  if (is.null(config)) {
    config <- getOption(".mcptools_config", file.path("~", ".config", "mcptools", "config.json"))
    if (!file.exists(path.expand(config))) {
      return(list())
    }
  }
  ellmer_tools <- mcptools::mcp_tools(config = config)
  lapply(ellmer_tools, deep_tool_from_ellmer, side_effects = "network", returns = "json")
}
