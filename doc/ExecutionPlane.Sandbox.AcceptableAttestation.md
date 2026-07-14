# `ExecutionPlane.Sandbox.AcceptableAttestation`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L297)

Closed set of acceptable Target attestation classes for one admission request.

# `t`

```elixir
@type t() :: %ExecutionPlane.Sandbox.AcceptableAttestation{
  classes: term(),
  contract_version: term(),
  priority_order: term()
}
```

# `dump`

```elixir
@spec dump(struct()) :: map()
```

# `empty?`

```elixir
@spec empty?(t()) :: boolean()
```

# `from_json!`

```elixir
@spec from_json!(String.t()) :: struct()
```

# `intersect`

```elixir
@spec intersect(t(), [String.t()]) :: [String.t()]
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
