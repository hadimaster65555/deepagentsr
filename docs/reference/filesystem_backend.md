# Create a local filesystem backend

The backend maps virtual paths to `root_dir` and blocks traversal,
symlink escapes, and secret-like paths by default.

## Usage

``` r
filesystem_backend(root_dir, virtual_mode = TRUE, deny_secret_paths = TRUE)
```

## Arguments

- root_dir:

  Local directory that forms the backend root.

- virtual_mode:

  Reserved for API compatibility; virtual paths are used.

- deny_secret_paths:

  Whether to deny common secret-like path names.

## Value

A backend object.
