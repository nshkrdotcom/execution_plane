# `ExecutionPlane.Contracts.NoEgressPolicy.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/no_egress_policy/v1.ex#L1)

Fail-closed no-egress policy for lower-runtime simulation boundaries.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.NoEgressPolicy.V1{
  contract_version: String.t(),
  denied_surfaces: map(),
  enforcement_boundary: String.t(),
  mode: String.t(),
  owner_repo: String.t(),
  policy_ref: String.t(),
  required_negative_evidence: [String.t()]
}
```

# `contract_version`

```elixir
@spec contract_version() :: String.t()
```

# `default_lower_boundary_policy!`

```elixir
@spec default_lower_boundary_policy!() :: t()
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
