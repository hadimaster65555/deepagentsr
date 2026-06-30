FilesystemBackend <- R6::R6Class(
  "FilesystemBackend",
  inherit = Backend,
  public = list(
    root_dir = NULL,
    root_real = NULL,
    virtual_mode = TRUE,
    deny_secret_paths = TRUE,

    initialize = function(root_dir, virtual_mode = TRUE, deny_secret_paths = TRUE) {
      self$root_dir <- root_dir
      self$virtual_mode <- virtual_mode
      self$deny_secret_paths <- deny_secret_paths
      dir_create(root_dir)
      self$root_real <- normalizePath(root_dir, winslash = "/", mustWork = TRUE)
    },

    exists = function(path) {
      file.exists(private$resolve(path, for_write = FALSE, must_exist = FALSE))
    },

    list = function(path = "/", recursive = FALSE) {
      host <- private$resolve(path, for_write = FALSE, must_exist = TRUE, allow_root = TRUE)
      if (file.exists(host) && !dir.exists(host)) {
        return(private$stat_row_from_host(host))
      }
      found <- list.files(host, recursive = recursive, all.files = TRUE, no.. = TRUE, full.names = TRUE)
      if (!length(found)) {
        return(empty_df(path = character(), type = character(), size = numeric()))
      }
      rows <- lapply(found, private$stat_row_from_host)
      do.call(rbind, rows)
    },

    read = function(path, binary = FALSE) {
      host <- private$resolve(path, for_write = FALSE, must_exist = TRUE, allow_root = FALSE)
      if (dir.exists(host)) {
        deep_abort("Cannot read a directory as a file: %s", normalize_vpath(path))
      }
      if (binary) {
        readBin(host, what = "raw", n = file.info(host)$size)
      } else {
        paste(readLines(host, warn = FALSE), collapse = "\n")
      }
    },

    write = function(path, content, overwrite = TRUE, binary = FALSE) {
      host <- private$resolve(path, for_write = TRUE, must_exist = FALSE, allow_root = FALSE)
      if (!overwrite && file.exists(host)) {
        deep_abort("File already exists: %s", normalize_vpath(path))
      }
      dir_create(dirname(host))
      if (binary) {
        writeBin(content, host)
      } else {
        writeLines(paste(content, collapse = "\n"), host, useBytes = TRUE)
      }
      invisible(normalize_vpath(path))
    },

    edit = function(path, search, replace, occurrence = "all") {
      mem <- memory_backend(list("/tmp" = self$read(path)))
      changed <- mem$edit("/tmp", search, replace, occurrence)
      self$write(path, mem$read("/tmp"), overwrite = TRUE)
      list(path = normalize_vpath(path), changed = changed$changed)
    },

    glob = function(pattern, path = "/") {
      root <- normalize_vpath(path)
      pattern <- if (startsWith(pattern, "/")) normalize_vpath(pattern) else normalize_vpath(file.path(root, pattern))
      files <- self$list(root, recursive = TRUE)
      files$path[vapply(files$path, glob_match, logical(1), pattern = pattern)]
    },

    grep = function(pattern, path = "/", ignore_case = FALSE) {
      files <- self$list(path, recursive = TRUE)
      files <- files[files$type == "file", , drop = FALSE]
      rows <- list()
      for (file in files$path) {
        lines <- split_text_lines(self$read(file))
        hits <- grep(pattern, lines, ignore.case = ignore_case)
        for (hit in hits) {
          rows[[length(rows) + 1]] <- data.frame(
            path = file,
            line_number = hit,
            line = lines[[hit]],
            stringsAsFactors = FALSE
          )
        }
      }
      if (!length(rows)) {
        return(empty_df(path = character(), line_number = integer(), line = character()))
      }
      do.call(rbind, rows)
    },

    delete = function(path) {
      host <- private$resolve(path, for_write = TRUE, must_exist = FALSE, allow_root = FALSE)
      if (file.exists(host)) {
        unlink(host, recursive = TRUE, force = FALSE)
      }
      invisible(normalize_vpath(path))
    },

    stat = function(path) {
      private$stat_row_from_host(private$resolve(path, for_write = FALSE, must_exist = TRUE, allow_root = TRUE))
    }
  ),
  private = list(
    resolve = function(path, for_write = FALSE, must_exist = FALSE, allow_root = TRUE) {
      vpath <- normalize_vpath(path, allow_root = allow_root)
      if (self$deny_secret_paths && path_has_forbidden_secret_name(vpath)) {
        deep_abort("Access to hidden or secret-like paths is denied by default: %s", vpath)
      }
      rel <- sub("^/", "", vpath)
      host <- if (identical(vpath, "/")) self$root_real else file.path(self$root_real, rel)
      check <- if (for_write && !file.exists(host)) dirname(host) else host
      while (!file.exists(check) && !identical(dirname(check), check)) {
        check <- dirname(check)
      }
      check_real <- normalizePath(check, winslash = "/", mustWork = TRUE)
      if (!private$under_root(check_real)) {
        deep_abort("Resolved path escapes filesystem backend root: %s", vpath)
      }
      if (file.exists(host)) {
        host_real <- normalizePath(host, winslash = "/", mustWork = TRUE)
        if (!private$under_root(host_real)) {
          deep_abort("Resolved path escapes filesystem backend root: %s", vpath)
        }
      } else if (must_exist) {
        deep_abort("Path does not exist: %s", vpath)
      }
      host
    },

    under_root = function(path) {
      identical(path, self$root_real) || startsWith(path, paste0(self$root_real, "/"))
    },

    host_to_vpath = function(host) {
      real <- normalizePath(host, winslash = "/", mustWork = TRUE)
      rel <- sub(paste0("^", gsub("([\\W])", "\\\\\\1", self$root_real)), "", real)
      normalize_vpath(rel)
    },

    stat_row_from_host = function(host) {
      info <- file.info(host)
      data.frame(
        path = private$host_to_vpath(host),
        type = if (isTRUE(info$isdir)) "dir" else "file",
        size = if (isTRUE(info$isdir)) NA_real_ else info$size,
        stringsAsFactors = FALSE
      )
    }
  )
)

#' Create a local filesystem backend
#'
#' The backend maps virtual paths to `root_dir` and blocks traversal, symlink
#' escapes, and secret-like paths by default.
#'
#' @param root_dir Local directory that forms the backend root.
#' @param virtual_mode Reserved for API compatibility; virtual paths are used.
#' @param deny_secret_paths Whether to deny common secret-like path names.
#' @return A backend object.
#' @export
filesystem_backend <- function(root_dir, virtual_mode = TRUE, deny_secret_paths = TRUE) {
  FilesystemBackend$new(
    root_dir = root_dir,
    virtual_mode = virtual_mode,
    deny_secret_paths = deny_secret_paths
  )
}
