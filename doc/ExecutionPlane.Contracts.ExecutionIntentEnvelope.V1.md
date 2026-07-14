# `ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/execution_intent_envelope/v1.ex#L1)

Spine-to-Execution neutral intent envelope.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1{
  attach_grant_ref: String.t(),
  attempt_ref: String.t() | nil,
  boundary_session_id: String.t(),
  cancellation_ref: String.t() | nil,
  contract_version: String.t(),
  credential_handle_refs: [String.t()],
  deadline_at: String.t() | nil,
  decision_id: String.t(),
  extensions: map(),
  family: String.t(),
  idempotency_key: String.t(),
  intent_id: String.t(),
  lease_ref: String.t() | nil,
  no_egress_posture_ref: String.t(),
  process_target_identity_ref: String.t() | nil,
  protocol: String.t(),
  requested_capabilities: [String.t()],
  route_template_ref: String.t() | nil,
  stream_target_identity_ref: String.t() | nil,
  target_auth_posture_ref: String.t(),
  target_ref: String.t(),
  trace_id: String.t() | nil,
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
