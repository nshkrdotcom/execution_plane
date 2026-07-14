# `ExecutionPlane.Contracts.BoundarySessionDescriptor.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/boundary_session_descriptor/v1.ex#L1)

Durable Spine-owned boundary/session descriptor.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.BoundarySessionDescriptor.V1{
  approval_refs: [String.t()],
  artifact_refs: [String.t()],
  attach_state: String.t(),
  boundary_session_id: String.t(),
  contract_version: String.t(),
  decision_id: String.t(),
  extensions: map(),
  lease_refs: [String.t()],
  persistence_posture: map() | nil,
  policy_echo: map(),
  session_status: String.t(),
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
