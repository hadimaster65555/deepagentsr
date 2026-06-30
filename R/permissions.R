PermissionEngine <- R6::R6Class(
  "PermissionEngine",
  public = list(
    rules = NULL,
    default_mode = NULL,

    initialize = function(rules = list(), default_mode = "allow") {
      self$rules <- rules
      self$default_mode <- match.arg(default_mode, c("allow", "deny", "interrupt"))
    },

    check = function(operation, path) {
      path <- normalize_vpath(path)
      for (rule in self$rules) {
        if (operation %in% rule$operations && match_any_path(rule$paths, path)) {
          return(list(mode = rule$mode, rule = rule))
        }
      }
      list(mode = self$default_mode, rule = NULL)
    }
  )
)

#' Create a filesystem permission rule
#'
#' @param operations Character vector of operations such as `"read"` or `"write"`.
#' @param paths Character vector of virtual path glob patterns.
#' @param mode One of `"allow"`, `"deny"`, or `"interrupt"`.
#' @return A permission rule.
#' @export
fs_permission <- function(operations, paths, mode = c("allow", "deny", "interrupt")) {
  mode <- match.arg(mode)
  structure(
    list(
      operations = as.character(operations),
      paths = vapply(paths, normalize_vpath, character(1)),
      mode = mode
    ),
    class = "deep_fs_permission"
  )
}
