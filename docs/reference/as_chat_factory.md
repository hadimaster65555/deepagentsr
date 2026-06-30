# Convert a model input to a chat factory

Convert a model input to a chat factory

## Usage

``` r
as_chat_factory(model)
```

## Arguments

- model:

  `NULL`, a fake chat, an `ellmer` chat-like object, a factory function,
  or a small string spec such as `"openai:gpt-4.1"`.

## Value

A function accepting `system_prompt`.
