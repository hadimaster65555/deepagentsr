CompositeBackend <- R6::R6Class(
  "CompositeBackend",
  inherit = Backend,
  public = list(
    default = NULL,
    routes = NULL,

    initialize = function(default = memory_backend(), routes = list()) {
      self$default <- default
      self$routes <- routes
      names(self$routes) <- vapply(names(self$routes), normalize_vpath, character(1))
    },

    exists = function(path) {
      routed <- private$route(path)
      routed$backend$exists(routed$child)
    },

    list = function(path = "/", recursive = FALSE) {
      path <- normalize_vpath(path)
      if (identical(path, "/")) {
        base <- self$default$list("/", recursive = recursive)
        route_rows <- lapply(names(self$routes), function(prefix) {
          data.frame(path = prefix, type = "dir", size = NA_real_, stringsAsFactors = FALSE)
        })
        return(unique(do.call(rbind, c(list(base), route_rows))))
      }
      routed <- private$route(path)
      rows <- routed$backend$list(routed$child, recursive = recursive)
      rows$path <- private$restore(routed$prefix, rows$path)
      rows
    },

    read = function(path, binary = FALSE) {
      routed <- private$route(path)
      routed$backend$read(routed$child, binary = binary)
    },

    write = function(path, content, overwrite = TRUE, binary = FALSE) {
      routed <- private$route(path)
      routed$backend$write(routed$child, content, overwrite = overwrite, binary = binary)
      invisible(path)
    },

    edit = function(path, search, replace, occurrence = "all") {
      routed <- private$route(path)
      out <- routed$backend$edit(routed$child, search, replace, occurrence)
      out$path <- private$restore(routed$prefix, out$path)
      out
    },

    glob = function(pattern, path = "/") {
      rows <- self$list(path, recursive = TRUE)
      rows$path[vapply(rows$path, glob_match, logical(1), pattern = normalize_vpath(pattern))]
    },

    grep = function(pattern, path = "/", ignore_case = FALSE) {
      routed <- private$route(path)
      rows <- routed$backend$grep(pattern, routed$child, ignore_case = ignore_case)
      rows$path <- private$restore(routed$prefix, rows$path)
      rows
    },

    delete = function(path) {
      routed <- private$route(path)
      routed$backend$delete(routed$child)
      invisible(path)
    },

    stat = function(path) {
      routed <- private$route(path)
      rows <- routed$backend$stat(routed$child)
      rows$path <- private$restore(routed$prefix, rows$path)
      rows
    }
  ),
  private = list(
    route = function(path) {
      path <- normalize_vpath(path)
      prefixes <- names(self$routes)
      hits <- prefixes[vapply(prefixes, function(prefix) {
        identical(path, prefix) || startsWith(path, ensure_trailing_slash(prefix))
      }, logical(1))]
      if (!length(hits)) {
        return(list(prefix = NULL, backend = self$default, child = path))
      }
      prefix <- hits[[which.max(nchar(hits))]]
      child <- sub(paste0("^", gsub("([\\W])", "\\\\\\1", prefix)), "", path)
      child <- if (identical(child, "")) "/" else normalize_vpath(child)
      list(prefix = prefix, backend = self$routes[[prefix]], child = child)
    },

    restore = function(prefix, child) {
      child <- normalize_vpath(child)
      if (is.null(prefix)) {
        return(child)
      }
      normalize_vpath(file.path(prefix, sub("^/", "", child)))
    }
  )
)

#' Create a composite virtual filesystem backend
#'
#' @param default Backend used when no route matches.
#' @param routes Named list of prefix routes to backend objects.
#' @return A backend object.
#' @export
composite_backend <- function(default = memory_backend(), routes = list()) {
  CompositeBackend$new(default = default, routes = routes)
}
