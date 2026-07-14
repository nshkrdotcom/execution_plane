# `ExecutionPlane.Codec`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L126)

Canonical JSON codec helpers for root boundary contracts.

# `decode!`

```elixir
@spec decode!(String.t(), module()) :: struct()
```

# `digest`

```elixir
@spec digest(struct() | map() | list() | String.t() | integer() | boolean() | nil) ::
  String.t()
```

# `encode!`

```elixir
@spec encode!(struct() | map()) :: String.t()
```

# `round_trip!`

```elixir
@spec round_trip!(
  struct(),
  module()
) :: struct()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
