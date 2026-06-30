find_test_env_file <- function(path = ".env") {
  dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    candidate <- file.path(dir, path)
    if (file.exists(candidate)) {
      return(candidate)
    }
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      return(path)
    }
    dir <- parent
  }
}

load_test_env_file <- function(path = ".env") {
  path <- find_test_env_file(path)
  if (!file.exists(path)) {
    return(invisible(character()))
  }
  lines <- readLines(path, warn = FALSE)
  for (line in lines) {
    line <- trimws(line)
    if (!nzchar(line) || startsWith(line, "#") || !grepl("=", line, fixed = TRUE)) {
      next
    }
    key <- trimws(sub("=.*$", "", line))
    value <- trimws(sub("^[^=]*=", "", line))
    value <- sub("^['\"]", "", value)
    value <- sub("['\"]$", "", value)
    if (!nzchar(Sys.getenv(key))) {
      do.call(Sys.setenv, stats::setNames(list(value), key))
    }
  }
  invisible()
}

discover_test_openai_models <- function() {
  load_test_env_file()
  api_key <- Sys.getenv("OPENAI_API_KEY")
  if (!nzchar(api_key)) {
    return(character())
  }
  handle <- curl::new_handle()
  curl::handle_setheaders(handle, Authorization = paste("Bearer", api_key))
  response <- curl::curl_fetch_memory("https://api.openai.com/v1/models", handle = handle)
  payload <- jsonlite::fromJSON(rawToChar(response$content))
  sort(grep("^gpt-(4\\.1|5)", payload$data$id, value = TRUE))
}

test_that("live OpenAI GPT 4.1 through 5.2 smoke suite passes", {
  skip_if_not(Sys.getenv("RUN_OPENAI_LIVE_TESTS") == "true")
  skip_if_not_installed("ellmer")
  skip_if_not_installed("curl")

  ids <- discover_test_openai_models()
  models <- intersect(c(
    "gpt-4.1",
    "gpt-4.1-mini",
    "gpt-4.1-nano",
    "gpt-5",
    "gpt-5-mini",
    "gpt-5-nano",
    "gpt-5.1",
    "gpt-5.2"
  ), ids)
  skip_if(!length(models), "No GPT 4.1 through 5.2 models are available to this API key")

  add <- deep_tool(
    function(x, y) x + y,
    name = "add",
    description = "Add two integers.",
    arguments = list(
      x = ellmer::type_integer("First integer"),
      y = ellmer::type_integer("Second integer")
    )
  )

  results <- lapply(models, function(model) {
    agent <- create_deep_agent(
      model = ellmer::chat_openai(model = model, echo = "none"),
      tools = list(add),
      system_prompt = "Use the add tool and return only the final number.",
      backend = memory_backend(),
      max_steps = 8
    )
    result <- agent$invoke("Use the tool to calculate 19 + 23.")
    list(
      model = model,
      ok = identical(result$status, "completed") &&
        grepl("42", result$text, fixed = TRUE) &&
        any(vapply(result$events, function(event) event$type == "tool_result", logical(1)))
    )
  })

  failed <- vapply(results, function(result) !isTRUE(result$ok), logical(1))
  expect_false(any(failed), info = paste(vapply(results[failed], `[[`, character(1), "model"), collapse = ", "))
})
