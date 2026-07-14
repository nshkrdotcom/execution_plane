# `ExecutionPlane.Lane.Capabilities`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L379)

Lane adapter capability descriptor.

# `t`

```elixir
@type t() :: %ExecutionPlane.Lane.Capabilities{
  contract_version: term(),
  lane_id: term(),
  metadata: term(),
  protocols: term(),
  supports_execute: term(),
  supports_stream: term(),
  surfaces: term()
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
