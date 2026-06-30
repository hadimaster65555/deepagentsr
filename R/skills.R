parse_skill_file <- function(path) {
  lines <- readLines(path, warn = FALSE)
  meta <- list()
  body_start <- 1L
  if (length(lines) >= 3 && identical(lines[[1]], "---")) {
    end <- which(lines[-1] == "---")
    if (length(end)) {
      end <- end[[1]] + 1L
      yaml_text <- paste(lines[2:(end - 1L)], collapse = "\n")
      meta <- yaml::yaml.load(yaml_text) %||% list()
      body_start <- end + 1L
    }
  }
  if (is.null(meta$name)) {
    meta$name <- basename(dirname(path))
  }
  if (is.null(meta$description)) {
    body <- paste(lines[body_start:length(lines)], collapse = "\n")
    meta$description <- trimws(strsplit(body, "\n\n", fixed = TRUE)[[1]][[1]] %||% "")
  }
  list(
    name = meta$name,
    description = meta$description,
    path = normalizePath(path, winslash = "/", mustWork = TRUE),
    metadata = meta
  )
}

#' Discover skills from directories
#'
#' @param roots Directories containing child directories with `SKILL.md`.
#' @return A named list of skill metadata records.
#' @export
discover_skills <- function(roots = NULL) {
  if (is.null(roots)) {
    return(list())
  }
  skills <- list()
  for (root in roots) {
    if (!dir.exists(root)) {
      next
    }
    candidates <- list.files(root, recursive = TRUE, full.names = TRUE)
    candidates <- candidates[basename(candidates) == "SKILL.md"]
    for (candidate in candidates) {
      skill <- parse_skill_file(candidate)
      skills[[skill$name]] <- skill
    }
  }
  skills
}

format_skill_inventory <- function(skills) {
  if (!length(skills)) {
    return("")
  }
  lines <- vapply(skills, function(skill) {
    sprintf("- %s: %s", skill$name, skill$description)
  }, character(1))
  paste(c("Available skills. Load full instructions only when relevant:", lines), collapse = "\n")
}
