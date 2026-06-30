Backend <- R6::R6Class(
  "Backend",
  public = list(
    exists = function(path) deep_abort("Backend$exists() is not implemented."),
    list = function(path = "/", recursive = FALSE) deep_abort("Backend$list() is not implemented."),
    read = function(path, binary = FALSE) deep_abort("Backend$read() is not implemented."),
    write = function(path, content, overwrite = TRUE, binary = FALSE) deep_abort("Backend$write() is not implemented."),
    edit = function(path, search, replace, occurrence = "all") deep_abort("Backend$edit() is not implemented."),
    glob = function(pattern, path = "/") deep_abort("Backend$glob() is not implemented."),
    grep = function(pattern, path = "/", ignore_case = FALSE) deep_abort("Backend$grep() is not implemented."),
    delete = function(path) deep_abort("Backend$delete() is not implemented."),
    stat = function(path) deep_abort("Backend$stat() is not implemented.")
  )
)
