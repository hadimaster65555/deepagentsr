RDSStoreBackend <- R6::R6Class(
  "RDSStoreBackend",
  inherit = Backend,
  public = list(
    path = NULL,
    memory = NULL,

    initialize = function(path) {
      self$path <- path
      dir_create(dirname(path))
      initial <- if (file.exists(path)) readRDS(path) else list()
      self$memory <- memory_backend(initial)
    },

    exists = function(path) self$memory$exists(path),
    list = function(path = "/", recursive = FALSE) self$memory$list(path, recursive),
    read = function(path, binary = FALSE) self$memory$read(path, binary),
    write = function(path, content, overwrite = TRUE, binary = FALSE) {
      self$memory$write(path, content, overwrite, binary)
      private$save()
      invisible(path)
    },
    edit = function(path, search, replace, occurrence = "all") {
      out <- self$memory$edit(path, search, replace, occurrence)
      private$save()
      out
    },
    glob = function(pattern, path = "/") self$memory$glob(pattern, path),
    grep = function(pattern, path = "/", ignore_case = FALSE) self$memory$grep(pattern, path, ignore_case),
    delete = function(path) {
      self$memory$delete(path)
      private$save()
      invisible(path)
    },
    stat = function(path) self$memory$stat(path)
  ),
  private = list(
    save = function() {
      saveRDS(self$memory$as_list(), self$path)
    }
  )
)

#' Create a durable RDS-backed virtual filesystem backend
#'
#' @param path RDS file path.
#' @return A backend object.
#' @export
rds_store_backend <- function(path) {
  RDSStoreBackend$new(path)
}
