make_event_stream <- function(events) {
  if (requireNamespace("coro", quietly = TRUE)) {
    factory <- coro::generator(function() {
      for (event in events) {
        coro::yield(event)
      }
    })
    return(factory())
  }
  structure(events, class = "deepagent_event_stream")
}

#' Print an agent event stream
#'
#' @param x A stream object returned by `agent$stream()`.
#' @param ... Unused.
#' @return Invisibly returns `x`.
#' @export
print.deepagent_event_stream <- function(x, ...) {
  cat(sprintf("<deepagent_event_stream: %d events>\n", length(x)))
  invisible(x)
}
