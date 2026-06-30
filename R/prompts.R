read_inst_prompt <- function(name) {
  path <- system.file("prompts", name, package = "deepagentsr", mustWork = FALSE)
  if (!nzchar(path) || !file.exists(path)) {
    return("")
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}
