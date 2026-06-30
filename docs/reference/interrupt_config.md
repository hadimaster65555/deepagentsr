# Configure a human-in-the-loop interrupt

Configure a human-in-the-loop interrupt

## Usage

``` r
interrupt_config(
  allowed_decisions = c("approve", "edit", "reject", "respond"),
  when = NULL
)
```

## Arguments

- allowed_decisions:

  Character vector of allowed decision names.

- when:

  Optional predicate metadata reserved for future use.

## Value

An interrupt configuration object.
