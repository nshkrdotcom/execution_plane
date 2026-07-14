# `ExecutionPlane.Contracts.AuthorityDecision.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/authority_decision/v1.ex#L1)

Packet-local Brain contract baseline carried across the lower stack.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.AuthorityDecision.V1{
  approval_profile: String.t(),
  boundary_class: String.t(),
  contract_version: String.t(),
  decision_hash: String.t(),
  decision_id: String.t(),
  egress_profile: String.t(),
  extensions: map(),
  policy_version: String.t(),
  request_id: String.t(),
  resource_profile: String.t(),
  tenant_id: String.t(),
  trust_profile: String.t(),
  workspace_profile: String.t()
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
