EventEmitter <- R6::R6Class(
  "EventEmitter",
  public = list(
    events = NULL,
    callbacks = NULL,

    initialize = function(callbacks = list()) {
      self$events <- list()
      self$callbacks <- callbacks %||% list()
    },

    emit = function(type, data = list(), thread_id = NULL, parent_id = NULL) {
      event <- list(
        id = new_id("evt"),
        type = type,
        time = now_iso(),
        thread_id = thread_id,
        parent_id = parent_id,
        data = data
      )
      self$events[[length(self$events) + 1]] <- event
      for (callback in self$callbacks) {
        callback(event)
      }
      event
    },

    get = function(thread_id = NULL) {
      if (is.null(thread_id)) {
        return(self$events)
      }
      Filter(function(event) identical(event$thread_id, thread_id), self$events)
    },

    clear = function(thread_id = NULL) {
      if (is.null(thread_id)) {
        self$events <- list()
      } else {
        self$events <- Filter(function(event) !identical(event$thread_id, thread_id), self$events)
      }
      invisible(self)
    },

    export_jsonl = function(path, thread_id = NULL) {
      events <- self$get(thread_id)
      lines <- vapply(
        events,
        jsonlite::toJSON,
        character(1),
        auto_unbox = TRUE,
        null = "null"
      )
      writeLines(lines, path, useBytes = TRUE)
      invisible(path)
    }
  )
)

#' Export agent events as JSON Lines
#'
#' @param agent A `DeepAgent` object.
#' @param path Destination JSONL path.
#' @param thread_id Optional thread id to filter events.
#' @return Invisibly returns `path`.
#' @export
export_events_jsonl <- function(agent, path, thread_id = NULL) {
  agent$event_emitter$export_jsonl(path, thread_id = thread_id)
}

#' Read a JSON Lines event trace
#'
#' @param path JSONL path produced by [export_events_jsonl()].
#' @return A list of event records.
#' @export
read_events_jsonl <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lapply(lines[nzchar(lines)], jsonlite::fromJSON, simplifyVector = FALSE)
}
