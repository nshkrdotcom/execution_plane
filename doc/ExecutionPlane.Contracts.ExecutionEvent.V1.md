# `ExecutionPlane.Contracts.ExecutionEvent.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/execution_event/v1.ex#L1)

Append-only raw execution fact emitted by the Execution Plane.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.ExecutionEvent.V1{
  contract_version: String.t(),
  event_id: String.t(),
  event_type: String.t(),
  lineage: ExecutionPlane.Contracts.lineage_t(),
  payload: map(),
  route_id: String.t(),
  timestamp: String.t()
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
