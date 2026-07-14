# `ExecutionPlane.Evidence`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L662)

Serializable execution evidence envelope.

# `t`

```elixir
@type t() :: %ExecutionPlane.Evidence{
  attestation_class: term(),
  authority_verifier_id: term(),
  contract_version: term(),
  emitted_at: term(),
  evidence_id: term(),
  evidence_type: term(),
  execution_ref: term(),
  lane_id: term(),
  payload: term(),
  persistence_posture: term(),
  policy_bundle_hash: term(),
  request_id: term(),
  target_id: term(),
  target_verifier_id: term()
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
