# `ExecutionPlane.Process.Transport.Surface.Adapter`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/surface/adapter.ex#L1)

Internal behaviour for execution-surface adapters owned by the core.

# `normalized_transport_options`

```elixir
@type normalized_transport_options() :: keyword()
```

# `capabilities`

```elixir
@callback capabilities() :: ExecutionPlane.Process.Transport.Surface.Capabilities.t()
```

# `normalize_transport_options`

```elixir
@callback normalize_transport_options(term()) ::
  {:ok, normalized_transport_options()}
  | {:error, {:invalid_transport_options, term()}}
```

# `surface_kind`

```elixir
@callback surface_kind() ::
  ExecutionPlane.Process.Transport.Surface.adapter_surface_kind()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
