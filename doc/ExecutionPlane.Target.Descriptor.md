# `ExecutionPlane.Target.Descriptor`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L425)

Verifier-validated Target routing descriptor.

# `t`

```elixir
@type t() :: %ExecutionPlane.Target.Descriptor{
  attestation_id: term(),
  attested_at: term(),
  attested_capability_classes: term(),
  contract_version: term(),
  expires_at: term(),
  lane_id: term(),
  metadata: term(),
  persistence_posture: term(),
  signature: term(),
  target_id: term(),
  verifier_id: term()
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
