# `ExecutionPlane.Runtimes.Process.Exit`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/runtimes/process/exit.ex#L1)

Normalized process exit information for the lower runtime substrate.

# `t`

```elixir
@type t() :: %ExecutionPlane.Runtimes.Process.Exit{
  code: non_neg_integer() | nil,
  reason: term(),
  signal: atom() | integer() | nil,
  status: :success | :exit | :signal | :error,
  stderr: binary() | nil
}
```

# `from_reason`

```elixir
@spec from_reason(
  term(),
  keyword()
) :: t()
```

# `successful?`

```elixir
@spec successful?(t()) :: boolean()
```

# `to_map`

```elixir
@spec to_map(t()) :: map()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
