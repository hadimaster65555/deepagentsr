validate_context_schema <- function(context, schema = NULL) {
  if (is.null(schema)) {
    return(invisible(context))
  }
  if (is.function(schema)) {
    result <- schema(context)
    if (isFALSE(result)) {
      deep_abort("`context` failed context_schema validation.")
    }
    return(invisible(context))
  }
  if (!is_named_list(schema)) {
    deep_abort("`context_schema` must be NULL, a function, or a named list.")
  }
  for (nm in names(schema)) {
    if (is.null(context[[nm]])) {
      deep_abort("`context` is missing required field `%s`.", nm)
    }
    expected <- schema[[nm]]
    if (is.character(expected) && length(expected) == 1) {
      ok <- switch(
        expected,
        character = is.character(context[[nm]]),
        numeric = is.numeric(context[[nm]]),
        integer = is.integer(context[[nm]]),
        logical = is.logical(context[[nm]]),
        list = is.list(context[[nm]]),
        inherits(context[[nm]], expected)
      )
      if (!isTRUE(ok)) {
        deep_abort("`context$%s` must be %s.", nm, expected)
      }
    } else if (is.function(expected) && isFALSE(expected(context[[nm]]))) {
      deep_abort("`context$%s` failed context_schema validation.", nm)
    }
  }
  invisible(context)
}
