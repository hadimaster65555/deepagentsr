ToolRegistry <- R6::R6Class(
  "ToolRegistry",
  public = list(
    tools = NULL,

    initialize = function(tools = list()) {
      self$tools <- new.env(parent = emptyenv())
      self$register_many(tools)
    },

    register = function(tool) {
      if (!inherits(tool, "deep_tool")) {
        deep_abort("Registered tools must be created with deep_tool().")
      }
      assign(tool$name, tool, envir = self$tools)
      invisible(tool)
    },

    register_many = function(tools) {
      if (is.null(tools)) {
        return(invisible(self))
      }
      for (tool in tools) {
        self$register(tool)
      }
      invisible(self)
    },

    get = function(name) {
      if (!exists(name, envir = self$tools, inherits = FALSE)) {
        deep_abort("Unknown tool: %s", name)
      }
      get(name, envir = self$tools, inherits = FALSE)
    },

    has = function(name) {
      exists(name, envir = self$tools, inherits = FALSE)
    },

    names = function() {
      sort(ls(self$tools, all.names = TRUE))
    },

    list = function() {
      stats::setNames(lapply(self$names(), self$get), self$names())
    },

    execute = function(name, arguments = list()) {
      tool <- self$get(name)
      if (!is.list(arguments)) {
        deep_abort("Tool arguments must be a list.")
      }
      do.call(tool$fun, arguments)
    },

    copy = function() {
      ToolRegistry$new(unname(self$list()))
    }
  )
)
