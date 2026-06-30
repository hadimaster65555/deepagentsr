check_aisdk_agent <- function(agent) {
  if (!has_method(agent, "run")) {
    deep_abort("`agent` must be an aisdk-like Agent with a $run() method.")
  }
  invisible(agent)
}

#' Wrap an aisdk Agent as a deepagentsr tool
#'
#' @param agent An `aisdk::Agent`-like object with a `$run()` method.
#' @param name Tool name.
#' @param description Tool description.
#' @param model Optional model override passed to `$run()`.
#' @param max_steps Maximum aisdk agent steps.
#' @return A [deep_tool()].
#' @export
aisdk_tool <- function(
    agent,
    name = NULL,
    description = NULL,
    model = NULL,
    max_steps = 10) {
  check_aisdk_agent(agent)
  name <- name %||% paste0(agent$name %||% "aisdk", "_agent")
  description <- description %||% agent$description %||% "Delegate a task to an aisdk Agent."
  deep_tool(
    fun = function(task, context = list()) {
      result <- agent$run(
        task = task,
        context = context,
        model = model,
        max_steps = max_steps
      )
      value_to_text(result)
    },
    name = name,
    description = description,
    side_effects = "none",
    returns = "text"
  )
}

#' Wrap an aisdk Agent as a direct deepagentsr subagent
#'
#' @param agent An `aisdk::Agent`-like object with a `$run()` method.
#' @param name Subagent name.
#' @param description Subagent description.
#' @param model Optional model override passed to `$run()`.
#' @param max_steps Maximum aisdk agent steps.
#' @return A [subagent()] configuration.
#' @export
aisdk_subagent <- function(
    agent,
    name = NULL,
    description = NULL,
    model = NULL,
    max_steps = 10) {
  check_aisdk_agent(agent)
  name <- name %||% agent$name %||% "aisdk-agent"
  description <- description %||% agent$description %||% "Delegates work to an aisdk Agent."
  subagent(
    name = name,
    description = description,
    system_prompt = "This subagent delegates directly to an aisdk Agent.",
    max_steps = max_steps,
    runner = function(task, context = list()) {
      result <- agent$run(
        task = task,
        context = context,
        model = model,
        max_steps = max_steps
      )
      value_to_text(result)
    }
  )
}
