# Usage

This guide targets `execution_plane_jsonrpc ~> 0.2.0`.

The main helper is `ExecutionPlane.JsonRpc.call/2`.

```elixir
{:ok, result} =
  ExecutionPlane.JsonRpc.call(%{
    command: "node",
    argv: ["client.js"],
    request: %{"method" => "ping", "params" => %{}}
  })
```

The package also exposes the lower JSON-RPC framing adapter for persistent
lane composition.
