# Create an opt-in local development shell tool

This is not a security sandbox. It is a local development convenience
that runs commands in a configured working directory with a timeout and
optional command allowlist. Do not register it for untrusted tasks.

## Usage

``` r
local_dev_shell_tool(
  root_dir,
  allowed_commands = NULL,
  timeout = 30,
  env = character()
)
```

## Arguments

- root_dir:

  Working directory for commands.

- allowed_commands:

  Optional character vector of allowed command names.

- timeout:

  Default timeout in seconds.

- env:

  Named character vector of environment variables to pass through.

## Value

A
[`deep_tool()`](https://hadimaster65555.github.io/deepagentsr/reference/deep_tool.md)
named `execute`.
