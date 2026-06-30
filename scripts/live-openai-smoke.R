#!/usr/bin/env Rscript

load_env_file <- function(path = ".env", overwrite = FALSE) {
  if (!file.exists(path)) {
    return(invisible(character()))
  }
  lines <- readLines(path, warn = FALSE)
  loaded <- character()
  for (line in lines) {
    line <- trimws(line)
    if (!nzchar(line) || startsWith(line, "#") || !grepl("=", line, fixed = TRUE)) {
      next
    }
    key <- trimws(sub("=.*$", "", line))
    value <- trimws(sub("^[^=]*=", "", line))
    value <- sub("^['\"]", "", value)
    value <- sub("['\"]$", "", value)
    if (!overwrite && nzchar(Sys.getenv(key))) {
      next
    }
    do.call(Sys.setenv, stats::setNames(list(value), key))
    loaded <- c(loaded, key)
  }
  invisible(loaded)
}

discover_openai_models <- function(pattern = "^gpt-(4\\.1|5)") {
  load_env_file()
  api_key <- Sys.getenv("OPENAI_API_KEY")
  if (!nzchar(api_key)) {
    stop("OPENAI_API_KEY is not set. Put it in .env or the process environment.", call. = FALSE)
  }
  handle <- curl::new_handle()
  curl::handle_setheaders(handle, Authorization = paste("Bearer", api_key))
  response <- curl::curl_fetch_memory("https://api.openai.com/v1/models", handle = handle)
  payload <- jsonlite::fromJSON(rawToChar(response$content))
  sort(grep(pattern, payload$data$id, value = TRUE))
}

select_test_models <- function(ids) {
  wanted <- c(
    "gpt-4.1",
    "gpt-4.1-mini",
    "gpt-4.1-nano",
    "gpt-5",
    "gpt-5-mini",
    "gpt-5-nano",
    "gpt-5.1",
    "gpt-5.1-mini",
    "gpt-5.2",
    "gpt-5.2-mini"
  )
  selected <- intersect(wanted, ids)
  if (length(selected)) {
    return(selected)
  }
  ids
}

run_smoke <- function(model) {
  library(deepagentsr)
  library(ellmer)

  add <- deep_tool(
    function(x, y) x + y,
    name = "add",
    description = "Add two integers.",
    arguments = list(
      x = ellmer::type_integer("First integer"),
      y = ellmer::type_integer("Second integer")
    )
  )

  agent <- create_deep_agent(
    model = ellmer::chat_openai(model = model, echo = "none"),
    tools = list(add),
    system_prompt = paste(
      "You are a smoke-test agent.",
      "Use the add tool to compute arithmetic.",
      "Return only the final number."
    ),
    backend = memory_backend(),
    max_steps = 8
  )
  result <- agent$invoke("Use the tool to calculate 19 + 23.")
  tool_events <- sum(vapply(result$events, function(event) event$type == "tool_result", logical(1)))
  ok <- identical(result$status, "completed") &&
    grepl("42", result$text, fixed = TRUE) &&
    tool_events >= 1
  list(
    model = model,
    ok = ok,
    status = result$status,
    text = result$text,
    tool_events = tool_events
  )
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) && identical(args[[1]], "--list")) {
  cat(paste(discover_openai_models(), collapse = "\n"), "\n", sep = "")
  quit(status = 0)
}

ids <- discover_openai_models()
models <- if (length(args)) args else select_test_models(ids)
if (!length(models)) {
  stop("No GPT 4.1 through 5.x model IDs were available from /v1/models.", call. = FALSE)
}

results <- lapply(models, function(model) {
  tryCatch(
    run_smoke(model),
    error = function(e) list(model = model, ok = FALSE, status = "error", text = conditionMessage(e), tool_events = 0L)
  )
})

df <- do.call(rbind, lapply(results, as.data.frame, stringsAsFactors = FALSE))
print(df, row.names = FALSE)
if (!all(df$ok)) {
  quit(status = 1)
}
