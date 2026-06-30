AgentThread <- R6::R6Class(
  "AgentThread",
  public = list(
    id = NULL,
    turns = NULL,
    todos = NULL,
    status = "new",
    pending_interrupt = NULL,
    chat = NULL,
    active_registry = NULL,
    ellmer_configured = FALSE,
    next_model_input = NULL,

    initialize = function(id = NULL) {
      self$id <- id %||% new_id("thread")
      self$turns <- list()
      self$todos <- list()
    },

    add_turn = function(role, content, metadata = list()) {
      turn <- list(
        role = role,
        content = paste(content, collapse = "\n"),
        metadata = metadata,
        time = now_iso()
      )
      self$turns[[length(self$turns) + 1]] <- turn
      invisible(turn)
    },

    state = function() {
      list(
        id = self$id,
        status = self$status,
        todos = self$todos,
        pending_interrupt = self$pending_interrupt,
        ellmer_configured = self$ellmer_configured,
        turns = self$turns
      )
    },

    restore = function(state) {
      self$id <- state$id %||% self$id
      self$status <- state$status %||% self$status
      self$todos <- state$todos %||% self$todos
      self$pending_interrupt <- state$pending_interrupt
      self$ellmer_configured <- isTRUE(state$ellmer_configured)
      self$turns <- state$turns %||% self$turns
      invisible(self)
    }
  )
)
