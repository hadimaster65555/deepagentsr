# Create a composite virtual filesystem backend

Create a composite virtual filesystem backend

## Usage

``` r
composite_backend(default = memory_backend(), routes = list())
```

## Arguments

- default:

  Backend used when no route matches.

- routes:

  Named list of prefix routes to backend objects.

## Value

A backend object.
