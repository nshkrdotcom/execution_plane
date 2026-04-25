# Usage

The main helper is `ExecutionPlane.Process.run/2`.

```elixir
{:ok, result} =
  ExecutionPlane.Process.run(%{
    command: "echo",
    argv: ["hello"]
  })
```

The package also exposes the lower process lane adapter and transport helpers
for more explicit runtime composition.
