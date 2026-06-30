#' Define a subagent
#'
#' @param name Subagent name.
#' @param description Description used by the supervisor.
#' @param system_prompt Subagent system prompt.
#' @param tools Optional tool list.
#' @param model Optional model or chat factory. Defaults to the supervisor model.
#' @param skills Optional skills.
#' @param max_steps Maximum loop steps.
#' @param runner Optional function used to execute the subagent directly.
#'   It receives `task` and `context` arguments. This is primarily for
#'   interop wrappers such as [aisdk_subagent()].
#' @return A subagent configuration.
#' @export
subagent <- function(
    name,
    description,
    system_prompt,
    tools = NULL,
    model = NULL,
    skills = NULL,
    max_steps = 10,
    runner = NULL) {
  structure(
    list(
      name = name,
      description = description,
      system_prompt = system_prompt,
      tools = tools %||% list(),
      model = model,
      skills = skills,
      max_steps = max_steps,
      runner = runner
    ),
    class = "deep_subagent"
  )
}

default_general_subagent <- function() {
  subagent(
    name = "general-purpose",
    description = "Handles focused subtasks and returns concise findings.",
    system_prompt = "You are a focused subagent. Complete the delegated task and return concise findings.",
    tools = list(),
    max_steps = 10
  )
}

normalize_subagents <- function(subagents) {
  out <- list()
  for (cfg in subagents %||% list()) {
    if (!inherits(cfg, "deep_subagent")) {
      deep_abort("Subagents must be created with subagent().")
    }
    out[[cfg$name]] <- cfg
  }
  if (is.null(out[["general-purpose"]])) {
    out[["general-purpose"]] <- default_general_subagent()
  }
  out
}
