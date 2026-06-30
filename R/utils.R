`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

deep_abort <- function(..., call. = FALSE) {
  stop(sprintf(...), call. = call.)
}

is_named_list <- function(x) {
  is.list(x) && !is.null(names(x)) && all(nzchar(names(x)))
}

now_iso <- function() {
  format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", usetz = FALSE)
}

new_id <- function(prefix = "id") {
  suffix <- paste(sample(c(letters, 0:9), 8, replace = TRUE), collapse = "")
  paste0(prefix, "-", format(Sys.time(), "%Y%m%d%H%M%OS3"), "-", suffix)
}

normalize_vpath <- function(path, allow_root = TRUE) {
  if (length(path) != 1 || is.na(path)) {
    deep_abort("`path` must be a single non-missing string.")
  }
  path <- gsub("\\\\", "/", as.character(path), fixed = FALSE)
  path <- trimws(path)
  if (identical(path, "")) {
    path <- "/"
  }
  if (startsWith(path, "~")) {
    deep_abort("Home-directory paths are not allowed in virtual paths: %s", path)
  }
  if (!startsWith(path, "/")) {
    path <- paste0("/", path)
  }
  parts <- strsplit(path, "/", fixed = TRUE)[[1]]
  parts <- parts[nzchar(parts) & parts != "."]
  if (any(parts == "..")) {
    deep_abort("Path traversal is not allowed in virtual paths: %s", path)
  }
  out <- paste0("/", paste(parts, collapse = "/"))
  if (identical(out, "/") && !allow_root) {
    deep_abort("Root path is not allowed here.")
  }
  out
}

vpath_parent <- function(path) {
  path <- normalize_vpath(path)
  if (identical(path, "/")) {
    return("/")
  }
  pieces <- strsplit(sub("^/", "", path), "/", fixed = TRUE)[[1]]
  if (length(pieces) <= 1) {
    return("/")
  }
  paste0("/", paste(pieces[-length(pieces)], collapse = "/"))
}

vpath_basename <- function(path) {
  path <- normalize_vpath(path)
  if (identical(path, "/")) "/" else utils::tail(strsplit(path, "/", fixed = TRUE)[[1]], 1)
}

ensure_trailing_slash <- function(path) {
  path <- normalize_vpath(path)
  if (identical(path, "/") || endsWith(path, "/")) path else paste0(path, "/")
}

path_has_forbidden_secret_name <- function(path) {
  path <- tolower(normalize_vpath(path))
  parts <- strsplit(path, "/", fixed = TRUE)[[1]]
  parts <- parts[nzchar(parts)]
  secret_dirs <- c(".ssh", ".aws", ".gcloud", ".config", "secrets", "secret")
  secret_files <- c(".env", ".renviron", ".rprofile", "credentials", "credentials.json")
  any(parts %in% secret_dirs) ||
    vpath_basename(path) %in% secret_files ||
    grepl("(password|credential|token|secret)", path)
}

glob_match <- function(pattern, path) {
  pattern <- normalize_vpath(pattern)
  path <- normalize_vpath(path)
  if (grepl("/\\*\\*$", pattern)) {
    prefix <- sub("/\\*\\*$", "", pattern)
    return(identical(path, prefix) || startsWith(path, ensure_trailing_slash(prefix)))
  }
  grepl(utils::glob2rx(pattern), path)
}

match_any_path <- function(patterns, path) {
  any(vapply(patterns, glob_match, logical(1), path = path))
}

value_to_text <- function(value) {
  if (is.null(value)) {
    return("NULL")
  }
  if (is.character(value) && length(value) == 1) {
    return(value)
  }
  if (is.atomic(value) && length(value) <= 20 && is.null(dim(value))) {
    return(paste(value, collapse = ", "))
  }
  jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", pretty = TRUE)
}

split_text_lines <- function(text) {
  text <- paste(text, collapse = "\n")
  strsplit(text, "\n", fixed = TRUE)[[1]]
}

preview_text <- function(text, max_lines = 8, max_chars = 1200) {
  text <- paste(text, collapse = "\n")
  lines <- utils::head(split_text_lines(text), max_lines)
  out <- paste(lines, collapse = "\n")
  if (nchar(out, type = "chars") > max_chars) {
    out <- paste0(substr(out, 1, max_chars), "\n...")
  }
  out
}

empty_df <- function(...) {
  cols <- list(...)
  as.data.frame(cols, stringsAsFactors = FALSE)
}

has_method <- function(x, name) {
  !is.null(x) && !is.null(x[[name]]) && is.function(x[[name]])
}

as_list_or_empty <- function(x) {
  if (is.null(x)) list() else x
}
