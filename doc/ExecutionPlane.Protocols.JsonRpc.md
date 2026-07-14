# `ExecutionPlane.Protocols.JsonRpc`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/protocols/json_rpc.ex#L1)

Minimal JSON-RPC framing support. Process-backed JSON-RPC is composed by a
direct lower-lane owner that depends on both JSON-RPC and process lanes.

# `execute`

```elixir
@spec execute(
  ExecutionPlane.Kernel.DispatchPlan.t(),
  keyword()
) :: {:ok, map()}
```

# `protocol`

```elixir
@spec protocol() :: String.t()
```

# `supports_intent?`

```elixir
@spec supports_intent?(struct() | map() | keyword()) :: boolean()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
