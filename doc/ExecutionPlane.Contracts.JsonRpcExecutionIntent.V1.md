# `ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/jsonrpc_execution_intent/v1.ex#L1)

JSON-RPC-family execution intent.

The lower transport binding and session-policy internals are Wave 1 carrier
fields only and remain provisional until Wave 3.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1{
  contract_version: String.t(),
  envelope: ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1.t(),
  protocol_schema: map(),
  request: map(),
  session_policy: map(),
  transport_binding: map()
}
```

# `contract_version`

```elixir
@spec contract_version() :: String.t()
```

# `dump`

```elixir
@spec dump(t()) :: map()
```

# `new`

```elixir
@spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
```

# `new!`

```elixir
@spec new!(map() | keyword() | t()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
