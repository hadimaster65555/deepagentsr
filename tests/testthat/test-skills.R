test_that("skills are discovered from SKILL.md frontmatter", {
  root <- tempfile("skills-")
  dir.create(file.path(root, "pkg"), recursive = TRUE)
  writeLines(c(
    "---",
    "name: pkg-dev",
    "description: Package development workflow.",
    "---",
    "",
    "# Skill"
  ), file.path(root, "pkg", "SKILL.md"))

  skills <- discover_skills(root)
  expect_true("pkg-dev" %in% names(skills))
  expect_equal(skills[["pkg-dev"]]$description, "Package development workflow.")
})

test_that("agent can read a discovered skill", {
  root <- tempfile("skills-")
  dir.create(file.path(root, "pkg"), recursive = TRUE)
  writeLines(c(
    "---",
    "name: pkg-dev",
    "description: Package development workflow.",
    "---",
    "Follow package checks."
  ), file.path(root, "pkg", "SKILL.md"))
  agent <- create_deep_agent(
    model = fake_chat(list(
      assistant_tool_call("read_skill", list(name = "pkg-dev")),
      assistant_message("done")
    )),
    skills = root
  )
  run <- agent$invoke("use skill")
  expect_equal(run$status, "completed")
  expect_true(any(grepl("Follow package checks", vapply(run$state$turns, `[[`, character(1), "content"))))
})
