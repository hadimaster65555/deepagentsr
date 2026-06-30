#' Convert a model input to a chat factory
#'
#' @param model `NULL`, a fake chat, an `ellmer` chat-like object, a factory
#'   function, or a small string spec such as `"openai:gpt-4.1"`.
#' @return A function accepting `system_prompt`.
#' @export
as_chat_factory <- function(model) {
  if (is.null(model)) {
    return(function(system_prompt = NULL) fake_chat(list(
      assistant_message("No model was configured for this agent.")
    )))
  }

  if (inherits(model, "FakeChat")) {
    return(function(system_prompt = NULL) model$clone_chat(reset = TRUE))
  }

  if (is.function(model)) {
    return(function(system_prompt = NULL) {
      tryCatch(
        model(system_prompt = system_prompt),
        error = function(e) model()
      )
    })
  }

  if (is.character(model) && length(model) == 1) {
    return(function(system_prompt = NULL) {
      if (!requireNamespace("ellmer", quietly = TRUE)) {
        deep_abort("Package `ellmer` is required for model specs.")
      }
      pieces <- strsplit(model, ":", fixed = TRUE)[[1]]
      provider <- pieces[[1]]
      model_name <- if (length(pieces) > 1) pieces[[2]] else NULL
      chat <- switch(
        provider,
        openai = ellmer::chat_openai(model = model_name, system_prompt = system_prompt),
        anthropic = ellmer::chat_anthropic(model = model_name, system_prompt = system_prompt),
        ollama = ellmer::chat_ollama(model = model_name, system_prompt = system_prompt),
        deep_abort("Unsupported model spec provider: %s", provider)
      )
      chat
    })
  }

  if (has_method(model, "clone_chat")) {
    return(function(system_prompt = NULL) model$clone_chat(reset = TRUE))
  }

  if (has_method(model, "clone")) {
    return(function(system_prompt = NULL) {
      chat <- model$clone(deep = TRUE)
      if (!is.null(system_prompt) && has_method(chat, "set_system_prompt")) {
        chat$set_system_prompt(system_prompt)
      }
      chat
    })
  }

  deep_abort("`model` must be NULL, a chat object, a chat factory, or a supported model spec.")
}
