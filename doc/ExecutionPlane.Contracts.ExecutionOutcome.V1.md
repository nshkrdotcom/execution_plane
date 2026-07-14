# `ExecutionPlane.Contracts.ExecutionOutcome.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/execution_outcome/v1.ex#L1)

Terminal or checkpointed raw execution outcome emitted by the Execution Plane.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.ExecutionOutcome.V1{
  artifacts: [term()],
  contract_version: String.t(),
  failure: ExecutionPlane.Contracts.Failure.t() | nil,
  family: String.t(),
  lineage: ExecutionPlane.Contracts.lineage_t(),
  metrics: map(),
  raw_payload: map(),
  route_id: String.t(),
  status: String.t()
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
