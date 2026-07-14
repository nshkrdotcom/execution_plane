# `ExecutionPlane.Contracts.ExecutionRoute.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/execution_route/v1.ex#L1)

Spine-owned durable route choice carried to and from the Execution Plane.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.ExecutionRoute.V1{
  contract_version: String.t(),
  family: String.t(),
  lineage: ExecutionPlane.Contracts.lineage_t(),
  placement_family: String.t(),
  protocol: String.t(),
  resolved_budget: map(),
  resolved_target: map(),
  route_id: String.t(),
  transport_family: String.t()
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
