#' Configure a human-in-the-loop interrupt
#'
#' @param allowed_decisions Character vector of allowed decision names.
#' @param when Optional predicate metadata reserved for future use.
#' @return An interrupt configuration object.
#' @export
interrupt_config <- function(
    allowed_decisions = c("approve", "edit", "reject", "respond"),
    when = NULL) {
  allowed <- c("approve", "edit", "reject", "respond")
  if (!all(allowed_decisions %in% allowed)) {
    deep_abort("Unsupported decision type: %s", paste(setdiff(allowed_decisions, allowed), collapse = ", "))
  }
  structure(
    list(allowed_decisions = allowed_decisions, when = when),
    class = "deep_interrupt_config"
  )
}

new_decision <- function(type, ...) {
  structure(c(list(type = type), list(...)), class = "deep_decision")
}

#' Human approval decision
#'
#' @return A decision object.
#' @export
decision_approve <- function() {
  new_decision("approve")
}

#' Human edit decision
#'
#' @param arguments Replacement tool arguments.
#' @return A decision object.
#' @export
decision_edit <- function(arguments) {
  new_decision("edit", arguments = arguments)
}

#' Human rejection decision
#'
#' @param message Message returned to the model.
#' @return A decision object.
#' @export
decision_reject <- function(message = "Rejected by user.") {
  new_decision("reject", message = message)
}

#' Human response decision
#'
#' @param message Message returned to the model.
#' @return A decision object.
#' @export
decision_respond <- function(message) {
  new_decision("respond", message = message)
}

validate_decision <- function(decision, allowed) {
  if (!inherits(decision, "deep_decision")) {
    deep_abort("`decision` must be created by a decision_*() helper.")
  }
  if (!decision$type %in% allowed) {
    deep_abort("Decision '%s' is not allowed here. Allowed: %s", decision$type, paste(allowed, collapse = ", "))
  }
  invisible(decision)
}
