FakeChat <- R6::R6Class(
  "FakeChat",
  public = list(
    script = NULL,
    cursor = 1L,

    initialize = function(script = list()) {
      self$script <- script
    },

    next_response = function(thread = NULL) {
      if (self$cursor > length(self$script)) {
        return(assistant_message(""))
      }
      out <- self$script[[self$cursor]]
      self$cursor <- self$cursor + 1L
      out
    },

    chat = function(input) {
      response <- self$next_response()
      if (identical(response$type, "message")) {
        response$text
      } else {
        deep_abort("Fake chat produced a tool call where a message was expected.")
      }
    },

    clone_chat = function(reset = TRUE) {
      fake <- FakeChat$new(self$script)
      if (!reset) {
        fake$cursor <- self$cursor
      }
      fake
    }
  )
)

#' Create a deterministic fake chat model
#'
#' @param script A list of [assistant_message()] and [assistant_tool_call()] records.
#' @return A fake chat object for tests and examples.
#' @export
fake_chat <- function(script = list()) {
  FakeChat$new(script)
}

#' Create a scripted assistant message
#'
#' @param text Message text.
#' @return A fake-chat script record.
#' @export
assistant_message <- function(text) {
  list(type = "message", text = text)
}

#' Create a scripted assistant tool call
#'
#' @param name Tool name.
#' @param arguments Tool arguments.
#' @return A fake-chat script record.
#' @export
assistant_tool_call <- function(name, arguments = list()) {
  list(type = "tool_call", name = name, arguments = arguments)
}
