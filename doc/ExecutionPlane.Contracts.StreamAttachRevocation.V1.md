# `ExecutionPlane.Contracts.StreamAttachRevocation.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/stream_attach_revocation/v1.ex#L1)

Revocation evidence proving an attached stream stopped after grant or lease revocation.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.StreamAttachRevocation.V1{
  attach_grant_ref: term(),
  authority_packet_ref: term(),
  contract_version: term(),
  correlation_id: term(),
  environment_ref: term(),
  idempotency_key: term(),
  installation_ref: term(),
  last_event_position: term(),
  lease_ref: term(),
  permission_decision_ref: term(),
  persistence_posture: term(),
  principal_ref: term(),
  project_ref: term(),
  release_manifest_ref: term(),
  resource_ref: term(),
  revocation_ref: term(),
  stream_ref: term(),
  system_actor_ref: term(),
  tenant_ref: term(),
  termination_ref: term(),
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
