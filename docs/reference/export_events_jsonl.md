# Export agent events as JSON Lines

Export agent events as JSON Lines

## Usage

``` r
export_events_jsonl(agent, path, thread_id = NULL)
```

## Arguments

- agent:

  A `DeepAgent` object.

- path:

  Destination JSONL path.

- thread_id:

  Optional thread id to filter events.

## Value

Invisibly returns `path`.
