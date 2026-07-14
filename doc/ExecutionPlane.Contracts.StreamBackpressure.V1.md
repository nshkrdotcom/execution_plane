# `ExecutionPlane.Contracts.StreamBackpressure.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/stream_backpressure/v1.ex#L1)

Deterministic stream pressure and termination evidence.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.StreamBackpressure.V1{
  authority_packet_ref: term(),
  budget_ref: term(),
  contract_version: term(),
  correlation_id: term(),
  diagnostics_ref: term(),
  environment_ref: term(),
  idempotency_key: term(),
  installation_ref: term(),
  last_heartbeat_at: term(),
  permission_decision_ref: term(),
  pressure_class: term(),
  principal_ref: term(),
  project_ref: term(),
  release_manifest_ref: term(),
  resource_ref: term(),
  stream_ref: term(),
  system_actor_ref: term(),
  tenant_ref: term(),
  termination_reason: term(),
  trace_id: term(),
  workspace_ref: term()
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
