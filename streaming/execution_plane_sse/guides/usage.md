# Usage

The main helpers are `ExecutionPlane.SSE.parse/1` and
`ExecutionPlane.SSE.stream/3`.

```elixir
{events, rest} = ExecutionPlane.SSE.parse("data: hello\n\n")
```

The stream helper wraps a Finch request and yields parsed SSE chunks together
with transport lifecycle items.
