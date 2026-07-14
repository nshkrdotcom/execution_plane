# `ExecutionPlane.ProcessExit`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process_exit.ex#L1)

Normalized process exit information shared by the runtime and provider profiles.

# `status`

```elixir
@type status() :: :success | :exit | :signal | :error
```

# `t`

```elixir
@type t() :: %ExecutionPlane.ProcessExit{
  code: non_neg_integer() | nil,
  reason: term(),
  signal: atom() | integer() | nil,
  status: status(),
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

Normalizes raw subprocess exit reasons into a stable struct.

This includes raw integer exit statuses, including the shifted values some
platforms report as `code * 256`.

# `successful?`

```elixir
@spec successful?(t()) :: boolean()
```

Returns `true` when the normalized exit represents success.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
