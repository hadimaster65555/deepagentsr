# Subagents, Skills, and Memory

``` r

library(deepagentsr)
```

Longer tasks benefit from isolating work. `deepagentsr` supports three
related mechanisms:

- subagents for focused delegated work;
- skills for on-demand procedural instructions;
- memory files for always-loaded project or user context.

## Subagents

Subagents are configured with
[`subagent()`](https://hadimaster65555.github.io/deepagentsr/reference/subagent.md)
and called through the supervisor’s built-in `task` tool. Each subagent
receives an isolated agent runtime with its own system prompt, tool
list, and model.

``` r

reviewer <- subagent(
  name = "reviewer",
  description = "Reviews short R package changes.",
  system_prompt = "You review R package changes and return concise findings.",
  model = fake_chat(list(assistant_message("No blocking issues found.")))
)

supervisor <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call(
      "task",
      list(description = "Review the latest package changes.", subagent = "reviewer")
    ),
    assistant_message("The reviewer found no blocking issues.")
  )),
  subagents = list(reviewer)
)

run <- supervisor$invoke("Review this package update.")
run$text
#> [1] "The reviewer found no blocking issues."
vapply(run$events, function(event) event$type, character(1))
#>  [1] "agent_start"    "tool_request"   "subagent_start" "subagent_event"
#>  [5] "subagent_event" "subagent_event" "subagent_end"   "tool_result"   
#>  [9] "model_message"  "agent_end"
```

A default `general-purpose` subagent is registered automatically. Add
named subagents when you want different prompts, tools, models, or step
limits for specific work.

## Skills

Skills are directories containing a `SKILL.md` file. The agent reads
only the inventory into the supervisor prompt; the full instructions are
loaded by the built-in `read_skill` tool when relevant.

``` r

skill_root <- tempfile("skills-")
skill_dir <- file.path(skill_root, "r-package-review")
dir.create(skill_dir, recursive = TRUE)

writeLines(
  c(
    "---",
    "name: r-package-review",
    "description: Review R package changes for tests, docs, and API consistency.",
    "---",
    "",
    "Check exported APIs, examples, tests, and package check output."
  ),
  file.path(skill_dir, "SKILL.md")
)

skills <- discover_skills(skill_root)
names(skills)
#> [1] "r-package-review"
skills[["r-package-review"]]$description
#> [1] "Review R package changes for tests, docs, and API consistency."
```

``` r

skill_agent <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call("read_skill", list(name = "r-package-review")),
    assistant_message("Loaded the review skill.")
  )),
  skills = skill_root
)

skill_run <- skill_agent$invoke("Use the package review skill.")
skill_run$text
#> [1] "Loaded the review skill."
```

## Memory

Memory files are always loaded into the assembled supervisor prompt.
They can come from the host filesystem or from the configured virtual
backend.

``` r

mem_backend <- memory_backend(list(
  "/AGENTS.md" = "Always prefer concise, testable examples in documentation."
))

memory_agent <- create_deep_agent(
  model = fake_chat(list(assistant_message("I will keep examples concise."))),
  backend = mem_backend,
  memory = "/AGENTS.md"
)

memory_run <- memory_agent$invoke("How should examples be written?")
memory_run$text
#> [1] "I will keep examples concise."
```

Use the virtual filesystem for writable or task-specific memory, and
regular files for project-wide instructions that should be version
controlled.

## aisdk interop

[`aisdk_tool()`](https://hadimaster65555.github.io/deepagentsr/reference/aisdk_tool.md)
wraps an [aisdk](https://github.com/YuLab-SMU/aisdk)-style Agent as a
tool. The wrapper only requires an object with a `$run()` method, so it
is easy to test without making
[aisdk](https://github.com/YuLab-SMU/aisdk) a hard dependency.

``` r

AgentLike <- R6::R6Class(
  "AgentLikeForVignette",
  public = list(
    name = "worker",
    description = "Does delegated work.",
    run = function(task, context = NULL, model = NULL, max_steps = 10, ...) {
      topic <- if (is.null(context) || is.null(context$topic)) "" else context$topic
      paste("ran", task, topic)
    }
  )
)

worker_tool <- aisdk_tool(AgentLike$new())
worker_tool$name
#> [1] "worker_agent"
worker_tool$fun("summarise", list(topic = "documentation"))
#> [1] "ran summarise documentation"
```

[`aisdk_subagent()`](https://hadimaster65555.github.io/deepagentsr/reference/aisdk_subagent.md)
exposes the same style of object as a direct subagent. This is useful
when you already use [aisdk](https://github.com/YuLab-SMU/aisdk) for
specialized agents and want the `deepagentsr` supervisor to delegate to
them through the standard `task` tool.

``` r

worker_agent <- create_deep_agent(
  model = fake_chat(list(
    assistant_tool_call("task", list(description = "summarise docs", subagent = "worker")),
    assistant_message("delegation complete")
  )),
  subagents = list(aisdk_subagent(AgentLike$new()))
)

worker_run <- worker_agent$invoke("Delegate this.")
worker_run$status
#> [1] "completed"
```
