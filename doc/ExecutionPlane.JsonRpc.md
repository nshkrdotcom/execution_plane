# `ExecutionPlane.JsonRpc`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/json_rpc.ex#L1)

Helper surface for JSON-RPC framing and direct owner composition.

This helper emits `JsonRpcExecutionIntent.v1`, resolves the local process
target used for the request/response exchange, and executes through the
kernel.

# `call`

```elixir
@spec call(
  map() | keyword(),
  keyword()
) ::
  {:ok, ExecutionPlane.Kernel.ExecutionResult.t()}
  | {:error, ExecutionPlane.Kernel.ExecutionResult.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
