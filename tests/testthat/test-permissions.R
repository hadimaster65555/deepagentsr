test_that("permission engine is first-match-wins", {
  engine <- deepagentsr:::PermissionEngine$new(list(
    fs_permission("write", "/memories/**", "interrupt"),
    fs_permission("write", "/memories/private/**", "deny")
  ))
  expect_equal(engine$check("write", "/memories/a.md")$mode, "interrupt")
  expect_equal(engine$check("read", "/memories/a.md")$mode, "allow")
})

test_that("filesystem permission interrupts agent tool calls", {
  agent <- create_deep_agent(
    model = fake_chat(list(
      assistant_tool_call("write_file", list(path = "/memories/a.md", content = "remember")),
      assistant_message("done")
    )),
    permissions = list(fs_permission("write", "/memories/**", "interrupt"))
  )

  run <- agent$invoke("write memory")
  expect_equal(run$status, "interrupted")
  expect_equal(run$pending$tool, "write_file")

  resumed <- agent$resume(run$thread_id, decision_approve())
  expect_equal(resumed$status, "completed")
  expect_equal(agent$backend$read("/memories/a.md"), "remember")
})
