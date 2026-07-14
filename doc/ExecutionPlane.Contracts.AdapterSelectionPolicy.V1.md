# `ExecutionPlane.Contracts.AdapterSelectionPolicy.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/adapter_selection_policy/v1.ex#L1)

Owner-repo adapter selection rule for Phase 6 lower simulation.

Selection is through configured owner registries or install-time profile
binding, never through public request-time `simulation` selectors.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.AdapterSelectionPolicy.V1{
  config_key: String.t(),
  contract_version: String.t(),
  default_value_when_unset: String.t(),
  fail_closed_action_when_misconfigured: String.t(),
  owner_repo: String.t(),
  selection_surface: String.t()
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
