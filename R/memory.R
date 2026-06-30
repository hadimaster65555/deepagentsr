load_memory_records <- function(memory = NULL, backend = NULL) {
  if (is.null(memory)) {
    return(list())
  }
  records <- list()
  for (path in memory) {
    content <- NULL
    if (startsWith(path, "/") && !is.null(backend) && backend$exists(path)) {
      content <- backend$read(path)
    } else if (file.exists(path)) {
      content <- paste(readLines(path, warn = FALSE), collapse = "\n")
    }
    if (!is.null(content)) {
      records[[path]] <- list(path = path, content = content)
    }
  }
  records
}

format_memory_records <- function(records) {
  if (!length(records)) {
    return("")
  }
  chunks <- vapply(records, function(record) {
    sprintf("Memory from %s:\n%s", record$path, record$content)
  }, character(1))
  paste(c("Always-loaded memory:", chunks), collapse = "\n\n")
}
