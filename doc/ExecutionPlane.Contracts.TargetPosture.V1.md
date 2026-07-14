# `ExecutionPlane.Contracts.TargetPosture.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/target_posture/v1.ex#L1)

Phase 5 target posture and attach authorization contract.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.TargetPosture.V1{
  allowed_attach_grant_refs: [String.t()],
  allowed_connector_instance_refs: [String.t()],
  allowed_credential_handle_refs: [String.t()],
  allowed_provider_account_refs: [String.t()],
  allowed_provider_families: [String.t()],
  boundary_session_id: String.t(),
  cleanup_refs: [String.t()],
  contract_version: String.t(),
  materialized_state_refs: [String.t()],
  multi_handle?: boolean(),
  no_egress_posture_ref: String.t(),
  persistence_posture: map() | nil,
  process_target_identity_ref: String.t() | nil,
  service_identity_ref: String.t() | nil,
  stream_target_identity_ref: String.t() | nil,
  target_auth_posture: String.t(),
  target_auth_posture_ref: String.t(),
  target_kind: String.t(),
  target_ref: String.t(),
  tenant_ref: String.t(),
  workspace_ref: String.t()
}
```

# `authorize_attach`

```elixir
@spec authorize_attach(
  t() | map() | keyword(),
  ExecutionPlane.Contracts.AttachGrant.V1.t() | map(),
  ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1.t() | map()
) :: {:ok, map()} | {:error, term()}
```

# `cleanup_event`

```elixir
@spec cleanup_event(t() | map() | keyword(), atom() | String.t()) :: map()
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
