# `ExecutionPlane.Contracts.AttachGrant.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/attach_grant/v1.ex#L2)

Phase 4 lease-bound attach grant for hazmat stream/session access.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.AttachGrant.V1{
  attach_grant_ref: String.t(),
  authority_packet_ref: String.t(),
  boundary_session_id: String.t() | nil,
  cleanup_refs: [String.t()],
  connector_instance_refs: [String.t()],
  contract_version: String.t(),
  correlation_id: String.t(),
  credential_handle_refs: [String.t()],
  environment_ref: String.t(),
  expires_at: String.t(),
  grant_scope: map(),
  hazmat_resource_ref: String.t(),
  idempotency_key: String.t(),
  installation_ref: String.t(),
  lease_ref: String.t(),
  no_egress_posture_ref: String.t() | nil,
  permission_decision_ref: String.t(),
  persistence_posture: map() | nil,
  principal_ref: String.t() | nil,
  process_target_identity_ref: String.t() | nil,
  project_ref: String.t(),
  provider_account_refs: [String.t()],
  release_manifest_ref: String.t(),
  resource_ref: String.t(),
  revocation_ref: String.t(),
  stream_target_identity_ref: String.t() | nil,
  system_actor_ref: String.t() | nil,
  target_auth_posture: String.t() | nil,
  target_auth_posture_ref: String.t() | nil,
  target_ref: String.t() | nil,
  tenant_ref: String.t(),
  trace_id: String.t(),
  workspace_ref: String.t()
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
