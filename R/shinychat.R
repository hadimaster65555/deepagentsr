#' Adapt an agent event stream for Shiny chat demos
#'
#' @param stream A stream returned by `agent$stream()`.
#' @return The same stream object. This lightweight adapter keeps the core
#'   package UI-free while giving Shiny examples a stable extension point.
#' @export
as_shinychat_stream <- function(stream) {
  stream
}
