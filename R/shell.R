#' Create an opt-in local development shell tool
#'
#' This is not a security sandbox. It is a local development convenience that
#' runs commands in a configured working directory with a timeout and optional
#' command allowlist. Do not register it for untrusted tasks.
#'
#' @param root_dir Working directory for commands.
#' @param allowed_commands Optional character vector of allowed command names.
#' @param timeout Default timeout in seconds.
#' @param env Named character vector of environment variables to pass through.
#' @return A [deep_tool()] named `execute`.
#' @export
local_dev_shell_tool <- function(
    root_dir,
    allowed_commands = NULL,
    timeout = 30,
    env = character()) {
  if (!requireNamespace("processx", quietly = TRUE)) {
    deep_abort("Package `processx` is required for local_dev_shell_tool().")
  }
  dir_create(root_dir)
  root <- normalizePath(root_dir, winslash = "/", mustWork = TRUE)
  if (!is.null(allowed_commands)) {
    allowed_commands <- as.character(allowed_commands)
  }

  deep_tool(
    fun = function(command, args = character(), timeout = NULL) {
      if (!is.null(allowed_commands) && !command %in% allowed_commands) {
        deep_abort("Command is not allowed: %s", command)
      }
      timeout <- timeout %||% 30
      result <- processx::run(
        command = command,
        args = as.character(args %||% character()),
        wd = root,
        env = env,
        timeout = timeout,
        error_on_status = FALSE,
        echo = FALSE
      )
      list(
        command = command,
        args = as.character(args %||% character()),
        status = result$status,
        stdout = result$stdout,
        stderr = result$stderr
      )
    },
    name = "execute",
    description = "Run an explicitly allowed local development command in the configured working directory.",
    side_effects = "execute",
    returns = "json",
    interrupt = TRUE
  )
}
