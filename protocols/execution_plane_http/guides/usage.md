# Usage

The main helper is `ExecutionPlane.HTTP.unary/2`.

```elixir
{:ok, result} =
  ExecutionPlane.HTTP.unary(%{
    url: "https://example.com/status",
    method: "GET"
  })
```

The package also exposes the lower lane adapter behavior for hosts that need to
register the HTTP lane explicitly.
