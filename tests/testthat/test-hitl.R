test_that("tool interrupts can be approved", {
  sent <- new.env(parent = emptyenv())
  sent$value <- FALSE
  send <- deep_tool(
    function(to) {
      sent$value <- to
      "sent"
    },
    name = "send_email",
    description = "Send email.",
    interrupt = TRUE
  )
  agent <- create_deep_agent(
    model = fake_chat(list(
      assistant_tool_call("send_email", list(to = "a@example.com")),
      assistant_message("done")
    )),
    tools = list(send)
  )

  run <- agent$invoke("send")
  expect_equal(run$status, "interrupted")
  expect_false(isTRUE(sent$value))

  resumed <- agent$resume(run$thread_id, decision_edit(list(to = "b@example.com")))
  expect_equal(resumed$status, "completed")
  expect_equal(sent$value, "b@example.com")
})

test_that("tool interrupts can be rejected", {
  send <- deep_tool(function() "sent", name = "send_email", description = "Send.", interrupt = TRUE)
  agent <- create_deep_agent(
    model = fake_chat(list(
      assistant_tool_call("send_email", list()),
      assistant_message("not sent")
    )),
    tools = list(send)
  )
  run <- agent$invoke("send")
  resumed <- agent$resume(run$thread_id, decision_reject("No."))
  expect_equal(resumed$text, "not sent")
})
