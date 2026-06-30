DeepAgent <- R6::R6Class(
  "DeepAgent",
  public = list(
    model = NULL,
    chat_factory = NULL,
    registry = NULL,
    backend = NULL,
    permission_engine = NULL,
    interrupt_on = NULL,
    subagents = NULL,
    skills = NULL,
    memory_records = NULL,
    context_manager = NULL,
    event_emitter = NULL,
    max_steps = NULL,
    system_prompt = NULL,
    debug = FALSE,
    name = NULL,
    threads = NULL,
    checkpointer = NULL,
    store = NULL,
    middleware = NULL,
    context_schema = NULL,

    initialize = function(
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
        context_budget = NULL,
        checkpointer = NULL,
        store = NULL,
        context_schema = NULL,
        max_steps = 30,
        debug = FALSE,
        name = NULL,
        ...) {
      self$model <- model
      self$chat_factory <- as_chat_factory(model)
      self$registry <- ToolRegistry$new(tools)
      self$backend <- backend
      self$permission_engine <- PermissionEngine$new(permissions)
      self$interrupt_on <- interrupt_on
      self$subagents <- normalize_subagents(subagents)
      self$skills <- discover_skills(skills)
      self$memory_records <- load_memory_records(memory, backend)
      self$middleware <- middleware %||% list()
      self$context_schema <- context_schema
      self$event_emitter <- EventEmitter$new(callbacks = self$middleware)
      context_budget <- context_budget %||% default_context_budget()
      self$context_manager <- ContextManager$new(context_budget, backend, self$event_emitter)
      self$max_steps <- max_steps
      self$system_prompt <- system_prompt %||% ""
      self$debug <- isTRUE(debug)
      self$name <- name %||% "deep-agent"
      self$threads <- new.env(parent = emptyenv())
      self$checkpointer <- checkpointer
      self$store <- store
    },

    invoke = function(input, thread_id = NULL, context = list(), files = list()) {
      validate_context_schema(context, self$context_schema)
      thread <- private$get_thread(thread_id)
      if (length(files)) {
        for (path in names(files)) {
          self$backend$write(path, files[[path]], overwrite = TRUE)
        }
      }
      thread$status <- "running"
      thread$active_registry <- private$runtime_registry(thread)
      if (is.null(thread$chat)) {
        thread$chat <- self$chat_factory(private$assembled_system_prompt(context))
      }
      thread$add_turn("user", input, list(context = context))
      thread$next_model_input <- input
      self$event_emitter$emit("agent_start", list(input = input, name = self$name), thread_id = thread$id)
      private$continue_loop(thread)
    },

    resume = function(thread_id, decision) {
      thread <- private$get_thread(thread_id, must_exist = TRUE)
      pending <- thread$pending_interrupt
      if (is.null(pending)) {
        deep_abort("Thread has no pending interrupt: %s", thread_id)
      }
      validate_decision(decision, pending$allowed_decisions)
      self$event_emitter$emit("interrupt_resolved", list(
        tool = pending$tool,
        decision = decision$type
      ), thread_id = thread$id)
      thread$pending_interrupt <- NULL
      thread$status <- "running"

      if (decision$type %in% c("reject", "respond")) {
        message <- decision$message %||% sprintf("Tool call %s was %s.", pending$tool, decision$type)
        thread$add_turn("tool", message, list(tool = pending$tool, decision = decision$type))
        return(private$continue_loop(thread))
      }

      args <- if (decision$type == "edit") decision$arguments else pending$arguments
      result <- private$execute_tool_call(
        thread = thread,
        name = pending$tool,
        arguments = args,
        bypass_interrupt = TRUE
      )
      if (identical(result$status, "interrupted")) {
        return(private$interrupt_result(thread))
      }
      thread$next_model_input <- paste(
        sprintf("The approved `%s` tool call completed.", pending$tool),
        "Tool result:",
        result$text,
        "Continue from this result and answer the original request.",
        sep = "\n"
      )
      private$continue_loop(thread)
    },

    stream = function(input, thread_id = NULL, context = list(), files = list()) {
      before <- length(self$get_events(thread_id))
      run <- self$invoke(input, thread_id = thread_id, context = context, files = files)
      events <- self$get_events(run$thread_id)
      new_events <- if (is.null(thread_id)) events else utils::tail(events, length(events) - before)
      make_event_stream(new_events)
    },

    stream_async = function(input, thread_id = NULL, context = list(), files = list()) {
      if (!requireNamespace("promises", quietly = TRUE)) {
        deep_abort("Package `promises` is required for stream_async().")
      }
      promises::promise_resolve(self$stream(
        input = input,
        thread_id = thread_id,
        context = context,
        files = files
      ))
    },

    get_state = function(thread_id = NULL) {
      if (is.null(thread_id)) {
        ids <- ls(self$threads, all.names = TRUE)
        return(stats::setNames(lapply(ids, function(id) self$get_state(id)), ids))
      }
      private$get_thread(thread_id, must_exist = TRUE)$state()
    },

    get_events = function(thread_id = NULL) {
      self$event_emitter$get(thread_id)
    },

    get_files = function(path = "/", thread_id = NULL) {
      self$backend$list(path, recursive = TRUE)
    },

    register_tool = function(tool) {
      self$registry$register(tool)
      invisible(tool)
    },

    register_subagent = function(config) {
      if (!inherits(config, "deep_subagent")) {
        deep_abort("`config` must be created with subagent().")
      }
      self$subagents[[config$name]] <- config
      invisible(config)
    },

    save_state = function(thread_id = NULL) {
      if (is.null(self$checkpointer)) {
        deep_abort("No checkpointer configured.")
      }
      threads <- if (is.null(thread_id)) {
        ids <- ls(self$threads, all.names = TRUE)
        lapply(ids, function(id) private$get_thread(id, must_exist = TRUE))
      } else {
        list(private$get_thread(thread_id, must_exist = TRUE))
      }
      invisible(vapply(threads, self$checkpointer$save_thread, character(1)))
    },

    load_state = function(thread_id) {
      if (is.null(self$checkpointer)) {
        deep_abort("No checkpointer configured.")
      }
      state <- self$checkpointer$load_thread(thread_id)
      if (is.null(state)) {
        deep_abort("No checkpoint found for thread id: %s", thread_id)
      }
      thread <- AgentThread$new(thread_id)
      thread$restore(state)
      assign(thread$id, thread, envir = self$threads)
      invisible(thread)
    }
  ),
  private = list(
    get_thread = function(thread_id = NULL, must_exist = FALSE) {
      if (is.null(thread_id)) {
        thread <- AgentThread$new()
        assign(thread$id, thread, envir = self$threads)
        return(thread)
      }
      if (!exists(thread_id, envir = self$threads, inherits = FALSE)) {
        if (!is.null(self$checkpointer)) {
          state <- self$checkpointer$load_thread(thread_id)
          if (!is.null(state)) {
            thread <- AgentThread$new(thread_id)
            thread$restore(state)
            assign(thread$id, thread, envir = self$threads)
            return(thread)
          }
        }
        if (must_exist) {
          deep_abort("Unknown thread id: %s", thread_id)
        }
        thread <- AgentThread$new(thread_id)
        assign(thread$id, thread, envir = self$threads)
        return(thread)
      }
      get(thread_id, envir = self$threads, inherits = FALSE)
    },

    assembled_system_prompt = function(context = list()) {
      pieces <- c(
        self$system_prompt,
        read_inst_prompt("base-system-prompt.md"),
        format_skill_inventory(self$skills),
        format_memory_records(self$memory_records)
      )
      paste(pieces[nzchar(pieces)], collapse = "\n\n")
    },

    runtime_registry = function(thread) {
      registry <- self$registry$copy()
      for (tool in private$builtin_tools(thread)) {
        registry$register(tool)
      }
      registry
    },

    builtin_tools = function(thread) {
      list(
        deep_tool(
          function(items) {
            thread$todos <- items
            self$event_emitter$emit("todo_update", list(items = items), thread_id = thread$id)
            list(status = "updated", items = items)
          },
          name = "write_todos",
          description = "Replace the agent todo list.",
          side_effects = "write",
          returns = "json"
        ),
        deep_tool(
          function() thread$todos,
          name = "read_todos",
          description = "Read the current agent todo list.",
          side_effects = "read",
          returns = "json"
        ),
        deep_tool(
          function(path = "/") {
            out <- self$backend$list(path, recursive = FALSE)
            self$event_emitter$emit("file_read", list(path = path, operation = "ls"), thread_id = thread$id)
            out
          },
          name = "ls",
          description = "List files in the virtual filesystem.",
          side_effects = "read",
          returns = "json"
        ),
        deep_tool(
          function(path, start_line = NULL, end_line = NULL) {
            text <- self$backend$read(path)
            lines <- split_text_lines(text)
            if (!is.null(start_line) || !is.null(end_line)) {
              start_line <- start_line %||% 1L
              end_line <- end_line %||% length(lines)
              lines <- lines[seq.int(max(1L, start_line), min(length(lines), end_line))]
              text <- paste(lines, collapse = "\n")
            }
            self$event_emitter$emit("file_read", list(path = path, operation = "read_file"), thread_id = thread$id)
            text
          },
          name = "read_file",
          description = "Read a virtual filesystem file.",
          side_effects = "read",
          returns = "text"
        ),
        deep_tool(
          function(path, content, overwrite = TRUE) {
            self$backend$write(path, content, overwrite = overwrite)
            self$event_emitter$emit("file_write", list(path = path, operation = "write_file"), thread_id = thread$id)
            list(path = normalize_vpath(path), written = TRUE)
          },
          name = "write_file",
          description = "Write a virtual filesystem file.",
          side_effects = "write",
          returns = "json"
        ),
        deep_tool(
          function(path, search, replace, occurrence = "all") {
            out <- self$backend$edit(path, search, replace, occurrence)
            self$event_emitter$emit("file_write", list(path = path, operation = "edit_file"), thread_id = thread$id)
            out
          },
          name = "edit_file",
          description = "Edit a text file by replacing text.",
          side_effects = "write",
          returns = "json"
        ),
        deep_tool(
          function(pattern, path = "/") self$backend$glob(pattern, path),
          name = "glob",
          description = "Find files by glob pattern.",
          side_effects = "read",
          returns = "json"
        ),
        deep_tool(
          function(pattern, path = "/", ignore_case = FALSE) self$backend$grep(pattern, path, ignore_case),
          name = "grep",
          description = "Search files by regular expression.",
          side_effects = "read",
          returns = "json"
        ),
        deep_tool(
          function(description, subagent = NULL, context = list()) private$run_subagent(description, subagent, context, thread),
          name = "task",
          description = "Delegate a focused task to a named subagent.",
          side_effects = "none",
          returns = "text"
        ),
        deep_tool(
          function(question, options = NULL) {
            paste("User input requested:", question)
          },
          name = "ask_user",
          description = "Ask the user for input and pause until a response is provided.",
          side_effects = "none",
          returns = "text",
          interrupt = TRUE
        ),
        deep_tool(
          function(name) {
            if (is.null(self$skills[[name]])) {
              deep_abort("Unknown skill: %s", name)
            }
            paste(readLines(self$skills[[name]]$path, warn = FALSE), collapse = "\n")
          },
          name = "read_skill",
          description = "Read the full SKILL.md instructions for a discovered skill.",
          side_effects = "read",
          returns = "text"
        )
      )
    },

    continue_loop = function(thread) {
      for (step in seq_len(self$max_steps)) {
        response <- private$next_response(thread)
        if (identical(response$type, "interrupted")) {
          return(private$interrupt_result(thread))
        }
        if (identical(response$type, "message")) {
          text <- response$text %||% ""
          thread$add_turn("assistant", text)
          thread$status <- "completed"
          self$event_emitter$emit("model_message", list(text = text), thread_id = thread$id)
          self$event_emitter$emit("agent_end", list(status = "completed", text = text), thread_id = thread$id)
          private$checkpoint_thread(thread)
          return(private$completed_result(thread, text))
        }
        if (identical(response$type, "tool_call")) {
          result <- private$execute_tool_call(thread, response$name, response$arguments %||% list())
          if (identical(result$status, "interrupted")) {
            return(private$interrupt_result(thread))
          }
          self$context_manager$maybe_summarize(thread)
          next
        }
        deep_abort("Unsupported model response type: %s", response$type %||% "<missing>")
      }
      thread$status <- "max_steps"
      self$event_emitter$emit("agent_end", list(status = "max_steps"), thread_id = thread$id)
      private$checkpoint_thread(thread)
      list(status = "max_steps", thread_id = thread$id, text = NULL, events = self$get_events(thread$id), state = thread$state())
    },

    next_response = function(thread) {
      chat <- thread$chat
      if (has_method(chat, "next_response")) {
        return(chat$next_response(thread))
      }
      if (has_method(chat, "chat")) {
        private$prepare_ellmer_chat(thread)
        input <- thread$next_model_input %||% private$conversation_text(thread)
        thread$next_model_input <- NULL
        text <- tryCatch(
          chat$chat(input),
          deepagent_interrupt = function(e) {
            return(structure(list(type = "interrupted"), class = "deepagent_response"))
          }
        )
        if (is.list(text) && identical(text$type, "interrupted")) {
          return(text)
        }
        return(assistant_message(value_to_text(text)))
      }
      deep_abort("The configured chat object does not support next_response() or chat().")
    },

    prepare_ellmer_chat = function(thread) {
      chat <- thread$chat
      if (!requireNamespace("ellmer", quietly = TRUE)) {
        return(invisible(FALSE))
      }
      tools <- thread$active_registry$list()
      ellmer_tools <- lapply(tools, function(tool) {
        as_ellmer_tool_proxy(tool, function(arguments) {
          result <- private$execute_tool_call(
            thread = thread,
            name = tool$name,
            arguments = arguments,
            bypass_interrupt = TRUE,
            emit_request = FALSE
          )
          if (identical(result$status, "error")) {
            deep_abort("%s", result$text)
          }
          result$text
        })
      })
      if (has_method(chat, "set_tools")) {
        chat$set_tools(ellmer_tools)
      } else if (has_method(chat, "register_tools")) {
        chat$register_tools(ellmer_tools)
      } else if (has_method(chat, "register_tool")) {
        for (tool in ellmer_tools) {
          chat$register_tool(tool)
        }
      }
      if (!isTRUE(thread$ellmer_configured) && has_method(chat, "on_tool_request")) {
        chat$on_tool_request(function(request) {
          name <- request@name
          arguments <- request@arguments
          if (thread$active_registry$has(name)) {
            tool <- thread$active_registry$get(name)
            self$event_emitter$emit("tool_request", list(tool = name, arguments = arguments), thread_id = thread$id)
            interrupt <- private$pending_interrupt_for_tool(tool, arguments, bypass_interrupt = FALSE)
            if (!is.null(interrupt)) {
              thread$pending_interrupt <- interrupt
              thread$status <- "interrupted"
              self$event_emitter$emit("interrupt_pending", interrupt, thread_id = thread$id)
              private$abort_interrupt()
            }
          }
          invisible()
        })
        thread$ellmer_configured <- TRUE
      }
      invisible(TRUE)
    },

    conversation_text = function(thread) {
      paste(vapply(thread$turns, function(turn) {
        sprintf("%s: %s", turn$role, turn$content)
      }, character(1)), collapse = "\n\n")
    },

    execute_tool_call = function(thread, name, arguments = list(), bypass_interrupt = FALSE, emit_request = TRUE) {
      registry <- thread$active_registry %||% private$runtime_registry(thread)
      if (isTRUE(emit_request)) {
        self$event_emitter$emit("tool_request", list(tool = name, arguments = arguments), thread_id = thread$id)
      }
      if (!registry$has(name)) {
        message <- sprintf("Unknown tool: %s", name)
        self$event_emitter$emit("tool_error", list(tool = name, error = message), thread_id = thread$id)
        thread$add_turn("tool", message, list(tool = name, error = TRUE))
        return(list(status = "error", text = message))
      }
      tool <- registry$get(name)

      interrupt <- private$pending_interrupt_for_tool(tool, arguments, bypass_interrupt)
      if (!is.null(interrupt)) {
        thread$pending_interrupt <- interrupt
        thread$status <- "interrupted"
        self$event_emitter$emit("interrupt_pending", interrupt, thread_id = thread$id)
        return(list(status = "interrupted"))
      }

      started <- proc.time()[["elapsed"]]
      result <- tryCatch(
        registry$execute(name, arguments),
        error = function(e) structure(list(message = conditionMessage(e)), class = "deep_tool_error")
      )
      duration <- proc.time()[["elapsed"]] - started
      if (inherits(result, "deep_tool_error")) {
        text <- paste("Tool error:", result$message)
        self$event_emitter$emit("tool_error", list(tool = name, error = result$message, duration = duration), thread_id = thread$id)
        thread$add_turn("tool", text, list(tool = name, error = TRUE))
        return(list(status = "error", text = text))
      }
      text <- self$context_manager$maybe_offload(result, kind = "tool_result", tool = name, thread_id = thread$id)
      self$event_emitter$emit("tool_result", list(tool = name, result = text, duration = duration), thread_id = thread$id)
      thread$add_turn("tool", text, list(tool = name))
      list(status = "ok", text = text, value = result)
    },

    abort_interrupt = function() {
      stop(structure(
        list(message = "Tool call interrupted pending human decision."),
        class = c("deepagent_interrupt", "error", "condition")
      ))
    },

    pending_interrupt_for_tool = function(tool, arguments, bypass_interrupt = FALSE) {
      if (isTRUE(bypass_interrupt)) {
        return(NULL)
      }
      permission <- private$file_permission(tool$name, arguments)
      if (!is.null(permission) && identical(permission$mode, "deny")) {
        deep_abort("Permission denied for %s on %s.", permission$operation, permission$path)
      }
      if (!is.null(permission) && identical(permission$mode, "interrupt")) {
        return(list(
          kind = "permission",
          tool = tool$name,
          arguments = arguments,
          allowed_decisions = c("approve", "edit", "reject"),
          reason = sprintf("Permission rule requires approval for %s on %s.", permission$operation, permission$path)
        ))
      }
      cfg <- self$interrupt_on[[tool$name]]
      if (is.null(cfg) && isTRUE(tool$interrupt)) {
        cfg <- interrupt_config()
      }
      if (is.null(cfg)) {
        return(NULL)
      }
      list(
        kind = "tool",
        tool = tool$name,
        arguments = arguments,
        allowed_decisions = cfg$allowed_decisions,
        reason = "Tool is configured to require approval."
      )
    },

    file_permission = function(tool_name, arguments) {
      op <- switch(
        tool_name,
        read_file = "read",
        ls = "read",
        glob = "read",
        grep = "read",
        write_file = "write",
        edit_file = "write",
        NULL
      )
      if (is.null(op)) {
        return(NULL)
      }
      path <- arguments$path %||% "/"
      if (tool_name == "write_file") {
        path <- arguments$path
      }
      checked <- self$permission_engine$check(op, path)
      c(checked, list(operation = op, path = normalize_vpath(path)))
    },

    run_subagent = function(description, subagent_name = NULL, context = list(), parent_thread) {
      name <- subagent_name %||% "general-purpose"
      cfg <- self$subagents[[name]]
      if (is.null(cfg)) {
        deep_abort("Unknown subagent: %s", name)
      }
      self$event_emitter$emit("subagent_start", list(name = name, description = description), thread_id = parent_thread$id)
      if (is.function(cfg$runner)) {
        result <- cfg$runner(description, context)
        self$event_emitter$emit("subagent_end", list(name = name, status = "completed"), thread_id = parent_thread$id)
        return(value_to_text(result))
      }
      child <- DeepAgent$new(
        model = cfg$model %||% self$model,
        tools = cfg$tools,
        system_prompt = cfg$system_prompt,
        middleware = self$middleware,
        subagents = list(),
        skills = cfg$skills,
        memory = NULL,
        backend = self$backend,
        permissions = self$permission_engine$rules,
        interrupt_on = self$interrupt_on,
        context_budget = self$context_manager$budget,
        max_steps = cfg$max_steps,
        debug = self$debug,
        name = cfg$name
      )
      run <- child$invoke(description, context = context)
      for (event in child$get_events()) {
        self$event_emitter$emit("subagent_event", event, thread_id = parent_thread$id)
      }
      self$event_emitter$emit("subagent_end", list(name = name, status = run$status), thread_id = parent_thread$id)
      run$text %||% value_to_text(run)
    },

    completed_result = function(thread, text) {
      list(
        status = "completed",
        thread_id = thread$id,
        text = text,
        events = self$get_events(thread$id),
        state = thread$state()
      )
    },

    interrupt_result = function(thread) {
      private$checkpoint_thread(thread)
      list(
        status = "interrupted",
        thread_id = thread$id,
        pending = thread$pending_interrupt,
        events = self$get_events(thread$id),
        state = thread$state()
      )
    },

    checkpoint_thread = function(thread) {
      if (!is.null(self$checkpointer) && has_method(self$checkpointer, "save_thread")) {
        self$checkpointer$save_thread(thread)
      }
      invisible(thread)
    }
  )
)
