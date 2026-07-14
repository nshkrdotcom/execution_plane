# `ExecutionPlane.Process.Transport.Surface.Registry`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/surface/registry.ex#L1)

Internal registry of built-in execution-surface adapters.

# `fetch_error`

```elixir
@type fetch_error() :: {:unsupported_surface_kind, atom() | term()}
```

# `adapter_selection_policy`

```elixir
@spec adapter_selection_policy() ::
  ExecutionPlane.Contracts.AdapterSelectionPolicy.V1.t()
```

# `fetch`

```elixir
@spec fetch(term()) :: {:ok, module()} | {:error, fetch_error()}
```

# `registered?`

```elixir
@spec registered?(term()) :: boolean()
```

# `supported_surface_kinds`

```elixir
@spec supported_surface_kinds() :: [atom(), ...]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
