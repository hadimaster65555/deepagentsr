#' Create a retrieval tool from an R search function
#'
#' @param search_fun Function with arguments `query` and `k`.
#' @param name Tool name.
#' @param description Tool description.
#' @return A [deep_tool()].
#' @export
rag_tool <- function(
    search_fun,
    name = "search_docs",
    description = "Search a retrieval index for relevant documents.") {
  if (!is.function(search_fun)) {
    deep_abort("`search_fun` must be a function.")
  }
  deep_tool(
    fun = function(query, k = 5) {
      search_fun(query = query, k = k)
    },
    name = name,
    description = description,
    side_effects = "read",
    returns = "json"
  )
}

#' Return optional RAG tools
#'
#' @param search_fun Optional search function to wrap with [rag_tool()].
#' @param store Optional Ragnar store object or path.
#' @param top_k Default number of chunks to retrieve from a Ragnar store.
#' @param ... Additional arguments passed to [rag_tool()].
#' @return A list of tools.
#' @export
rag_tools <- function(search_fun = NULL, store = NULL, top_k = 3L, ...) {
  if (!is.null(search_fun)) {
    return(list(rag_tool(search_fun, ...)))
  }
  if (!is.null(store)) {
    if (!requireNamespace("ragnar", quietly = TRUE)) {
      deep_abort("Package `ragnar` is required for Ragnar store retrieval tools.")
    }
    return(list(rag_tool(
      search_fun = function(query, k = top_k) {
        ragnar::ragnar_retrieve(store, text = query, top_k = k)
      },
      ...
    )))
  }
  if (!requireNamespace("ragnar", quietly = TRUE)) {
    return(list())
  }
  list()
}
