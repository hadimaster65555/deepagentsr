# Adapt an agent event stream for Shiny chat demos

Adapt an agent event stream for Shiny chat demos

## Usage

``` r
as_shinychat_stream(stream)
```

## Arguments

- stream:

  A stream returned by `agent$stream()`.

## Value

The same stream object. This lightweight adapter keeps the core package
UI-free while giving Shiny examples a stable extension point.
