# `ExecutionPlane.Admission.Request`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L495)

Runtime-client admission request.

# `t`

```elixir
@type t() :: %ExecutionPlane.Admission.Request{
  acceptable_attestation: term(),
  authority_ref: term(),
  constraints: term(),
  contract_version: term(),
  lane_id: term(),
  metadata: term(),
  operation: term(),
  payload: term(),
  placement: term(),
  provenance: term(),
  request_id: term(),
  sandbox_profile: term()
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
