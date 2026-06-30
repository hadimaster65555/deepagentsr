# Create a filesystem permission rule

Create a filesystem permission rule

## Usage

``` r
fs_permission(operations, paths, mode = c("allow", "deny", "interrupt"))
```

## Arguments

- operations:

  Character vector of operations such as `"read"` or `"write"`.

- paths:

  Character vector of virtual path glob patterns.

- mode:

  One of `"allow"`, `"deny"`, or `"interrupt"`.

## Value

A permission rule.
