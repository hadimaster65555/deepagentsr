library(shiny)
library(shinychat)
library(deepagentsr)

make_agent <- function() {
  if (requireNamespace("ellmer", quietly = TRUE) && nzchar(Sys.getenv("OPENAI_API_KEY"))) {
    return(create_deep_agent(
      model = ellmer::chat_openai(model = Sys.getenv("OPENAI_MODEL", "gpt-4.1"), echo = "none"),
      system_prompt = "You are a concise assistant in a Shiny demo.",
      backend = memory_backend()
    ))
  }

  create_deep_agent(
    model = fake_chat(list(
      assistant_message("This demo is running without an API key. Set OPENAI_API_KEY to use a live OpenAI model.")
    )),
    backend = memory_backend()
  )
}

ui <- fluidPage(
  tags$head(tags$title("deepagentsr shinychat demo")),
  chat_ui(
    "chat",
    messages = list("Ask a question. The app routes each message through a deepagentsr agent."),
    width = "min(760px, 100%)",
    height = "70vh"
  )
)

server <- function(input, output, session) {
  observeEvent(input$chat_user_input, {
    agent <- make_agent()
    stream <- as_shinychat_stream(agent$stream(input$chat_user_input))
    events <- if (inherits(stream, "coro_generator_instance")) {
      coro::collect(stream)
    } else {
      stream
    }
    end <- Filter(function(event) identical(event$type, "agent_end"), events)
    text <- if (length(end)) {
      utils::tail(end, 1)[[1]]$data$text
    } else {
      "No final response was produced."
    }
    chat_append("chat", text)
  })
}

shinyApp(ui, server)
