# Usage

The main helper is `ExecutionPlane.WebSocket.stream/4`.

```elixir
{:ok, %{status: 101, headers: headers, stream: stream}} =
  ExecutionPlane.WebSocket.stream(
    "wss://example.com/socket",
    [{"accept", "application/json"}]
  )
```

The stream yields frame events, close events, and transport errors while it
manages the connection lifecycle.
