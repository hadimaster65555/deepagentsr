# Configure context budget behavior

Configure context budget behavior

## Usage

``` r
context_budget(
  max_input_tokens = NULL,
  offload_tokens = 20000,
  summarize_at = 0.85,
  keep_recent = 0.1,
  token_estimator = NULL
)
```

## Arguments

- max_input_tokens:

  Optional model input budget.

- offload_tokens:

  Approximate token threshold for offloading values.

- summarize_at:

  Fraction of budget at which summarization should occur.

- keep_recent:

  Fraction of turns to keep during summarization.

- token_estimator:

  Function used to estimate tokens from text.

## Value

A context budget record.
