# `ExecutionPlane.Runtime.NodeDescriptor`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L745)

Runtime client descriptor returned by describe/1.

# `t`

```elixir
@type t() :: %ExecutionPlane.Runtime.NodeDescriptor{
  authority_verifier: term(),
  contract_version: term(),
  contract_version_range: term(),
  metadata: term(),
  node_id: term(),
  registered_lanes: term(),
  registered_target_verifiers: term(),
  registration_complete: term(),
  verified_targets: term()
}
```

# `dump`

```elixir
@spec dump(struct()) :: map()
```

# `from_json!`

```elixir
@spec from_json!(String.t()) :: struct()
```

# `load`

```elixir
@spec load(map() | keyword() | struct()) :: {:ok, struct()} | {:error, Exception.t()}
```

# `load!`

```elixir
@spec load!(map() | keyword() | struct()) :: struct()
```

# `new`

```elixir
@spec new(map() | keyword() | struct()) :: {:ok, struct()} | {:error, Exception.t()}
```

# `new!`

```elixir
@spec new!(map() | keyword() | struct()) :: struct()
```

# `to_json!`

```elixir
@spec to_json!(struct()) :: String.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
