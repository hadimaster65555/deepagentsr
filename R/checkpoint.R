RDSCheckpointer <- R6::R6Class(
  "RDSCheckpointer",
  public = list(
    path = NULL,

    initialize = function(path) {
      self$path <- path
      dir_create(dirname(path))
      if (!file.exists(path)) {
        saveRDS(list(), path)
      }
    },

    save_thread = function(thread) {
      states <- private$read()
      states[[thread$id]] <- thread$state()
      saveRDS(states, self$path)
      invisible(thread$id)
    },

    load_thread = function(thread_id) {
      private$read()[[thread_id]]
    },

    list_threads = function() {
      names(private$read())
    }
  ),
  private = list(
    read = function() {
      if (!file.exists(self$path)) {
        return(list())
      }
      readRDS(self$path)
    }
  )
)

#' Create an RDS checkpointer
#'
#' @param path Destination `.rds` file for thread state.
#' @return A checkpointer object.
#' @export
rds_checkpointer <- function(path) {
  RDSCheckpointer$new(path)
}
