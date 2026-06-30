#' Create a deep agent
#'
#' @param model Optional chat object, chat factory, fake chat, or model spec.
#' @param tools List of [deep_tool()] objects.
#' @param system_prompt Additional supervisor instructions.
#' @param middleware Optional list of event callback functions. Each receives
#'   one event record.
#' @param subagents List of [subagent()] configurations.
#' @param skills Optional skill root directories.
#' @param memory Optional memory files.
#' @param backend Virtual filesystem backend.
#' @param permissions List of [fs_permission()] rules.
#' @param interrupt_on Named list of [interrupt_config()] objects.
#' @param context_schema Optional context validator. Use a function accepting
#'   `context`, or a named list mapping required context fields to type names
#'   or predicate functions.
#' @param checkpointer Optional durable checkpointer, such as [rds_checkpointer()].
#' @param store Optional durable storage backend reserved for integrations.
#' @param max_steps Maximum agent loop steps.
#' @param context_budget Context budget configuration.
#' @param debug Whether to print debug output.
#' @param name Agent name.
#' @return A `DeepAgent` R6 object.
#' @export
create_deep_agent <- function(
    model = NULL,
    tools = list(),
    system_prompt = NULL,
    middleware = list(),
    subagents = list(),
    skills = NULL,
    memory = NULL,
    backend = memory_backend(),
    permissions = list(),
    interrupt_on = list(),
    context_schema = NULL,
    checkpointer = NULL,
    store = NULL,
    max_steps = 30,
    context_budget = NULL,
    debug = FALSE,
    name = NULL) {
  DeepAgent$new(
    model = model,
    tools = tools,
    system_prompt = system_prompt,
    middleware = middleware,
    subagents = subagents,
    skills = skills,
    memory = memory,
    backend = backend,
    permissions = permissions,
    interrupt_on = interrupt_on,
    context_schema = context_schema,
    context_budget = context_budget,
    checkpointer = checkpointer,
    store = store,
    max_steps = max_steps,
    debug = debug,
    name = name
  )
}
