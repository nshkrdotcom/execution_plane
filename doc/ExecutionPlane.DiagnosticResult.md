# `ExecutionPlane.DiagnosticResult`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/diagnostic_result.ex#L1)

Structured result emitted by the diagnostic execution lane.

# `attestation`

```elixir
@type attestation() :: :weak_local
```

# `status`

```elixir
@type status() :: :ok | :error | :timeout
```

# `t`

```elixir
@type t() :: %ExecutionPlane.DiagnosticResult{
  attestation: attestation(),
  execution_time_ms: non_neg_integer(),
  operation: String.t(),
  payload: map(),
  status: status(),
  target_class: String.t()
}
```

# `dump`

```elixir
@spec dump(t()) :: map()
```

# `new`

```elixir
@spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
```

# `new!`

```elixir
@spec new!(map() | keyword() | t()) :: t()
```

# `replace`

```elixir
@spec replace(t(), status(), map()) :: t()
```

# `with_elapsed`

```elixir
@spec with_elapsed(t(), non_neg_integer()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
