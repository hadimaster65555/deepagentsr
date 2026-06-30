#' Configure context budget behavior
#'
#' @param max_input_tokens Optional model input budget.
#' @param offload_tokens Approximate token threshold for offloading values.
#' @param summarize_at Fraction of budget at which summarization should occur.
#' @param keep_recent Fraction of turns to keep during summarization.
#' @param token_estimator Function used to estimate tokens from text.
#' @return A context budget record.
#' @export
context_budget <- function(
    max_input_tokens = NULL,
    offload_tokens = 20000,
    summarize_at = 0.85,
    keep_recent = 0.10,
    token_estimator = NULL) {
  structure(
    list(
      max_input_tokens = max_input_tokens,
      offload_tokens = offload_tokens,
      summarize_at = summarize_at,
      keep_recent = keep_recent,
      token_estimator = token_estimator %||% function(text) ceiling(nchar(text, type = "chars") / 4)
    ),
    class = "deep_context_budget"
  )
}

default_context_budget <- function() {
  context_budget()
}

ContextManager <- R6::R6Class(
  "ContextManager",
  public = list(
    budget = NULL,
    backend = NULL,
    emitter = NULL,

    initialize = function(budget = context_budget(), backend = memory_backend(), emitter = EventEmitter$new()) {
      self$budget <- budget
      self$backend <- backend
      self$emitter <- emitter
    },

    estimate_tokens = function(text) {
      self$budget$token_estimator(paste(text, collapse = "\n"))
    },

    maybe_offload = function(value, kind = "tool_result", tool = NULL, thread_id = NULL) {
      text <- value_to_text(value)
      approx <- self$estimate_tokens(text)
      if (is.null(self$budget$offload_tokens) || approx <= self$budget$offload_tokens) {
        return(text)
      }
      date <- format(Sys.Date(), "%Y-%m-%d")
      id <- new_id("offload")
      content_path <- normalize_vpath(file.path("/internal/offloads", date, paste0(id, ".txt")))
      meta_path <- normalize_vpath(file.path("/internal/offloads", date, paste0(id, ".json")))
      self$backend$write(content_path, text, overwrite = TRUE)
      self$backend$write(meta_path, jsonlite::toJSON(list(
        id = id,
        kind = kind,
        tool = tool,
        created_at = now_iso(),
        approx_tokens = approx,
        content_path = content_path
      ), auto_unbox = TRUE, pretty = TRUE), overwrite = TRUE)
      self$emitter$emit("context_offload", list(
        path = content_path,
        metadata_path = meta_path,
        approx_tokens = approx,
        tool = tool,
        kind = kind
      ), thread_id = thread_id)
      paste(
        sprintf("Large %s offloaded to %s.", kind, content_path),
        "Preview:",
        preview_text(text),
        "Use read_file() or grep() to inspect the full result.",
        sep = "\n"
      )
    },

    write_transcript = function(thread) {
      id <- new_id("summary")
      path <- normalize_vpath(file.path("/internal/transcripts", thread$id, paste0(id, ".md")))
      turns <- vapply(thread$turns, function(turn) {
        sprintf("## %s\n\n%s\n", turn$role, turn$content)
      }, character(1))
      self$backend$write(path, paste(turns, collapse = "\n"), overwrite = TRUE)
      self$emitter$emit("context_summary", list(path = path), thread_id = thread$id)
      path
    },

    maybe_summarize = function(thread) {
      max_tokens <- self$budget$max_input_tokens
      if (is.null(max_tokens) || !length(thread$turns)) {
        return(NULL)
      }
      active_text <- paste(vapply(thread$turns, function(turn) {
        paste(turn$role, turn$content, sep = ": ")
      }, character(1)), collapse = "\n\n")
      approx <- self$estimate_tokens(active_text)
      threshold <- max_tokens * self$budget$summarize_at
      if (approx < threshold || length(thread$turns) <= 2) {
        return(NULL)
      }

      keep_count <- max(1L, ceiling(length(thread$turns) * self$budget$keep_recent))
      keep_count <- min(keep_count, length(thread$turns) - 1L)
      transcript_path <- self$write_transcript(thread)
      older <- utils::head(thread$turns, length(thread$turns) - keep_count)
      recent <- utils::tail(thread$turns, keep_count)
      summary <- private$build_summary(older, transcript_path, approx)
      thread$turns <- c(list(summary), recent)
      self$emitter$emit("context_summary", list(
        path = transcript_path,
        approx_tokens_before = approx,
        kept_turns = keep_count,
        summarized_turns = length(older)
      ), thread_id = thread$id)
      summary
    }
  ),
  private = list(
    build_summary = function(turns, transcript_path, approx_tokens) {
      snippets <- vapply(utils::tail(turns, 8), function(turn) {
        sprintf("- %s: %s", turn$role, preview_text(turn$content, max_lines = 2, max_chars = 240))
      }, character(1))
      list(
        role = "summary",
        content = paste(
          "Earlier conversation was compacted.",
          sprintf("Full transcript: %s", transcript_path),
          sprintf("Approximate tokens before compaction: %s", approx_tokens),
          "Recent older-turn preview:",
          paste(snippets, collapse = "\n"),
          sep = "\n"
        ),
        metadata = list(path = transcript_path, kind = "context_summary"),
        time = now_iso()
      )
    }
  )
)
