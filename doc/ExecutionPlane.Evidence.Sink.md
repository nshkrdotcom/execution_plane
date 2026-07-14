# `ExecutionPlane.Evidence.Sink`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L720)

Evidence sink behaviour registered by node hosts.

# `emit`

```elixir
@callback emit(
  ExecutionPlane.Evidence.t(),
  keyword()
) :: :ok | {:error, term()}
```

# `flush`

```elixir
@callback flush(keyword()) :: :ok | {:error, term()}
```

# `sink_id`

```elixir
@callback sink_id() :: String.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
