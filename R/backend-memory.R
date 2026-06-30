MemoryBackend <- R6::R6Class(
  "MemoryBackend",
  inherit = Backend,
  public = list(
    files = NULL,

    initialize = function(initial = list()) {
      self$files <- new.env(parent = emptyenv())
      if (length(initial)) {
        if (is.null(names(initial))) {
          deep_abort("`initial` must be a named list of virtual paths.")
        }
        for (nm in names(initial)) {
          self$write(nm, initial[[nm]], overwrite = TRUE)
        }
      }
    },

    as_list = function() {
      paths <- ls(self$files, all.names = TRUE)
      stats::setNames(lapply(paths, function(path) get(path, envir = self$files, inherits = FALSE)), paths)
    },

    exists = function(path) {
      path <- normalize_vpath(path)
      exists(path, envir = self$files, inherits = FALSE) ||
        any(startsWith(ls(self$files, all.names = TRUE), ensure_trailing_slash(path)))
    },

    list = function(path = "/", recursive = FALSE) {
      path <- normalize_vpath(path)
      paths <- sort(ls(self$files, all.names = TRUE))
      if (exists(path, envir = self$files, inherits = FALSE)) {
        return(private$stat_rows(path))
      }
      prefix <- ensure_trailing_slash(path)
      under <- paths[startsWith(paths, prefix)]
      if (!length(under)) {
        return(empty_df(path = character(), type = character(), size = numeric()))
      }
      if (recursive) {
        return(do.call(rbind, lapply(under, private$stat_rows)))
      }
      rel <- sub(paste0("^", gsub("([\\W])", "\\\\\\1", prefix)), "", under)
      first <- vapply(strsplit(rel, "/", fixed = TRUE), `[[`, character(1), 1)
      child_paths <- unique(if (identical(path, "/")) paste0("/", first) else paste0(prefix, first))
      rows <- lapply(child_paths, private$stat_rows)
      do.call(rbind, rows)
    },

    read = function(path, binary = FALSE) {
      path <- normalize_vpath(path, allow_root = FALSE)
      if (!exists(path, envir = self$files, inherits = FALSE)) {
        deep_abort("File does not exist: %s", path)
      }
      value <- get(path, envir = self$files, inherits = FALSE)
      if (binary) {
        if (is.raw(value)) value else charToRaw(paste(value, collapse = "\n"))
      } else {
        if (is.raw(value)) rawToChar(value) else paste(value, collapse = "\n")
      }
    },

    write = function(path, content, overwrite = TRUE, binary = FALSE) {
      path <- normalize_vpath(path, allow_root = FALSE)
      if (!overwrite && exists(path, envir = self$files, inherits = FALSE)) {
        deep_abort("File already exists: %s", path)
      }
      assign(path, if (binary) content else paste(content, collapse = "\n"), envir = self$files)
      invisible(path)
    },

    edit = function(path, search, replace, occurrence = "all") {
      text <- self$read(path)
      updated <- private$replace_occurrence(text, search, replace, occurrence)
      self$write(path, updated, overwrite = TRUE)
      list(path = normalize_vpath(path), changed = !identical(text, updated))
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
      path <- normalize_vpath(path, allow_root = FALSE)
      if (exists(path, envir = self$files, inherits = FALSE)) {
        rm(list = path, envir = self$files)
      }
      invisible(path)
    },

    stat = function(path) {
      private$stat_rows(normalize_vpath(path))
    }
  ),
  private = list(
    stat_rows = function(path) {
      path <- normalize_vpath(path)
      is_file <- exists(path, envir = self$files, inherits = FALSE)
      if (is_file) {
        value <- get(path, envir = self$files, inherits = FALSE)
        size <- if (is.raw(value)) length(value) else nchar(paste(value, collapse = "\n"), type = "bytes")
        type <- "file"
      } else if (any(startsWith(ls(self$files, all.names = TRUE), ensure_trailing_slash(path)))) {
        size <- NA_real_
        type <- "dir"
      } else {
        deep_abort("Path does not exist: %s", path)
      }
      data.frame(path = path, type = type, size = size, stringsAsFactors = FALSE)
    },

    replace_occurrence = function(text, search, replace, occurrence) {
      if (!nzchar(search)) {
        deep_abort("`search` must not be empty.")
      }
      if (identical(occurrence, "all")) {
        return(gsub(search, replace, text, fixed = TRUE))
      }
      if (identical(occurrence, "first")) {
        return(sub(search, replace, text, fixed = TRUE))
      }
      if (is.numeric(occurrence) && length(occurrence) == 1 && occurrence >= 1) {
        locs <- gregexpr(search, text, fixed = TRUE)[[1]]
        if (identical(locs[[1]], -1L) || length(locs) < occurrence) {
          return(text)
        }
        start <- locs[[occurrence]]
        end <- start + attr(locs, "match.length")[[occurrence]] - 1
        return(paste0(substr(text, 1, start - 1), replace, substr(text, end + 1, nchar(text))))
      }
      deep_abort("`occurrence` must be 'all', 'first', or a positive number.")
    }
  )
)

#' Create an in-memory virtual filesystem backend
#'
#' @param initial Optional named list mapping virtual paths to contents.
#' @return A backend object.
#' @export
memory_backend <- function(initial = list()) {
  MemoryBackend$new(initial = initial)
}
