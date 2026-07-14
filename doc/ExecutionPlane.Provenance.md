# `ExecutionPlane.Provenance`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L206)

Execution provenance for governed node admission and direct lower-lane owners.

# `t`

```elixir
@type t() :: %ExecutionPlane.Provenance{
  admission_ref: term(),
  contract_version: term(),
  details: term(),
  kind: term(),
  owner: term()
}
```

# `direct?`

```elixir
@spec direct?(t()) :: boolean()
```

# `direct_lower_lane_owner`

```elixir
@spec direct_lower_lane_owner(String.t() | atom(), map()) :: t()
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

# `node_admitted`

```elixir
@spec node_admitted(map() | keyword()) :: t()
```

# `to_json!`

```elixir
@spec to_json!(struct()) :: String.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
