#' Define an agent tool
#'
#' @param fun R function implementing the tool.
#' @param name Tool name exposed to the model.
#' @param description Tool description.
#' @param arguments Optional argument schema, compatible with `ellmer::tool()`.
#'   Missing schemas are inferred from `fun` formals as generic JSON types.
#' @param side_effects Side-effect metadata.
#' @param returns Return type metadata.
#' @param interrupt Whether the tool should pause for approval before execution.
#' @param timeout Optional timeout metadata.
#' @param max_output_tokens Approximate output token threshold before offloading.
#' @param tags Optional tags.
#' @return A `deep_tool` object.
#' @export
deep_tool <- function(
    fun,
    name = NULL,
    description,
    arguments = list(),
    side_effects = c("none", "read", "write", "network", "execute"),
    returns = c("text", "json", "file", "image", "data"),
    interrupt = FALSE,
    timeout = NULL,
    max_output_tokens = 20000,
    tags = character()) {
  if (!is.function(fun)) {
    deep_abort("`fun` must be a function.")
  }
  side_effects <- match.arg(side_effects, several.ok = TRUE)
  returns <- match.arg(returns)
  if (is.null(name) || !nzchar(name)) {
    name <- paste0("tool_", paste(sample(c(letters, 0:9), 8, replace = TRUE), collapse = ""))
  }
  arguments <- normalize_tool_arguments(fun, arguments)
  structure(
    list(
      fun = fun,
      name = name,
      description = description,
      arguments = arguments,
      side_effects = side_effects,
      returns = returns,
      interrupt = isTRUE(interrupt),
      timeout = timeout,
      max_output_tokens = max_output_tokens,
      tags = tags
    ),
    class = "deep_tool"
  )
}

#' Convert a deep tool to an ellmer tool
#'
#' @param tool A `deep_tool`.
#' @return An `ellmer` tool definition.
#' @export
as_ellmer_tool <- function(tool) {
  if (!inherits(tool, "deep_tool")) {
    deep_abort("`tool` must be a deep_tool.")
  }
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    deep_abort("Package `ellmer` is required to convert tools.")
  }
  ellmer::tool(
    fun = tool$fun,
    description = tool$description,
    arguments = as_ellmer_arguments(tool$arguments),
    name = tool$name
  )
}

as_ellmer_tool_proxy <- function(tool, executor) {
  if (!inherits(tool, "deep_tool")) {
    deep_abort("`tool` must be a deep_tool.")
  }
  if (!is.function(executor)) {
    deep_abort("`executor` must be a function.")
  }
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    deep_abort("Package `ellmer` is required to convert tools.")
  }
  proxy_fun <- make_tool_proxy_fun(tool, executor)
  ellmer::tool(
    fun = proxy_fun,
    description = tool$description,
    arguments = as_ellmer_arguments(tool$arguments),
    name = tool$name
  )
}

make_tool_proxy_fun <- function(tool, executor) {
  proxy <- function() NULL
  formals(proxy) <- formals(tool$fun)
  env <- new.env(parent = baseenv())
  env$executor <- executor
  body(proxy) <- quote({
    call_args <- as.list(match.call(expand.dots = FALSE))[-1]
    args <- lapply(call_args, eval, envir = parent.frame())
    executor(args)
  })
  environment(proxy) <- env
  proxy
}

deep_tool_from_ellmer <- function(tool, side_effects = "network", returns = "json") {
  if (!inherits(tool, "ellmer::ToolDef")) {
    deep_abort("`tool` must be an ellmer ToolDef.")
  }
  deep_tool(
    fun = tool,
    name = tool@name,
    description = tool@description,
    arguments = as.list(tool@arguments@properties),
    side_effects = side_effects,
    returns = returns
  )
}

deep_type <- function(
    kind,
    description = NULL,
    required = TRUE,
    items = NULL,
    properties = list(),
    additional_properties = FALSE) {
  structure(
    list(
      kind = kind,
      description = description,
      required = required,
      items = items,
      properties = properties,
      additional_properties = additional_properties
    ),
    class = "deep_type_spec"
  )
}

normalize_tool_arguments <- function(fun, arguments = list()) {
  arguments <- arguments %||% list()
  formal_names <- names(formals(fun))
  formal_names <- formal_names[formal_names != "..."]
  if (!length(formal_names)) {
    return(list())
  }
  if (length(arguments) && (is.null(names(arguments)) || any(!nzchar(names(arguments))))) {
    deep_abort("`arguments` must be a named list.")
  }
  extras <- setdiff(names(arguments), formal_names)
  if (length(extras)) {
    deep_abort(
      "`arguments` contains names not present in `fun`: %s",
      paste(extras, collapse = ", ")
    )
  }
  missing <- setdiff(formal_names, names(arguments))
  if (!length(missing)) {
    return(arguments[formal_names])
  }
  fmls <- formals(fun)
  for (nm in missing) {
    arguments[[nm]] <- infer_tool_argument(nm, fmls[[nm]])
  }
  arguments[formal_names]
}

infer_tool_argument <- function(name, default) {
  has_default <- !is.symbol(default) || !identical(as.character(default), "")
  required <- !has_default
  lname <- tolower(name)
  description <- sprintf("Argument `%s`.", name)

  if (lname %in% c("ignore_case", "overwrite", "recursive", "binary")) {
    return(deep_type("boolean", description, required = required))
  }
  if (grepl("(^n$|count|line|limit|max|min|number|steps|timeout|occurrence)", lname)) {
    return(deep_type("integer", description, required = required))
  }
  if (lname %in% c("args", "items", "options", "tools", "tags")) {
    return(deep_type(
      "array",
      description,
      required = required,
      items = deep_type("string", sprintf("Item for `%s`.", name))
    ))
  }
  if (lname %in% c("context", "metadata", "params", "files")) {
    return(deep_type(
      "object",
      description,
      required = required
    ))
  }

  if (has_default) {
    if (isTRUE(default) || isFALSE(default)) {
      return(deep_type("boolean", description, required = required))
    }
    if (is.numeric(default)) {
      kind <- if (identical(default, as.integer(default))) "integer" else "number"
      return(deep_type(kind, description, required = required))
    }
    if (is.list(default)) {
      return(deep_type("object", description, required = required))
    }
  }

  deep_type("string", description, required = required)
}

as_ellmer_arguments <- function(arguments) {
  lapply(arguments, as_ellmer_argument)
}

as_ellmer_argument <- function(argument) {
  if (!inherits(argument, "deep_type_spec")) {
    return(argument)
  }
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    deep_abort("Package `ellmer` is required to convert tool argument schemas.")
  }
  switch(
    argument$kind,
    string = ellmer::type_string(argument$description, required = argument$required),
    integer = ellmer::type_integer(argument$description, required = argument$required),
    number = ellmer::type_number(argument$description, required = argument$required),
    boolean = ellmer::type_boolean(argument$description, required = argument$required),
    array = ellmer::type_array(
      items = as_ellmer_argument(argument$items %||% deep_type("string")),
      description = argument$description,
      required = argument$required
    ),
    object = {
      properties <- lapply(argument$properties %||% list(), as_ellmer_argument)
      do.call(
        ellmer::type_object,
        c(
          list(
            .description = argument$description,
            .required = argument$required,
            .additional_properties = argument$additional_properties
          ),
          properties
        )
      )
    },
    deep_abort("Unsupported tool argument type: %s", argument$kind)
  )
}
