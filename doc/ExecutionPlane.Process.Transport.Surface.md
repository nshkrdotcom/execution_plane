# `ExecutionPlane.Process.Transport.Surface`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/surface.ex#L1)

Legacy compatibility shell for the public execution-surface contract.

Execution Plane now owns the `execution_surface` contract. This module keeps
the historical public shape so existing callers can continue to reason about
narrow placement without leaking command or provider semantics.

This contract is intentionally narrow:

- `surface_kind` selects the runtime surface
- `transport_options` carries transport-only data
- `target_id`, `lease_ref`, `surface_ref`, and `boundary_class` stay typed
- `observability` remains an opaque metadata bag

Provider family, command selection, and process launch arguments do not
belong in `ExecutionSurface`.

# `adapter_surface_kind`

```elixir
@type adapter_surface_kind() :: atom()
```

# `boundary_class`

```elixir
@type boundary_class() :: atom() | String.t() | nil
```

# `contract_version`

```elixir
@type contract_version() :: String.t()
```

# `dispatch`

```elixir
@type dispatch() :: %{start: function(), start_link: function(), run: function()}
```

# `projected_t`

```elixir
@type projected_t() :: %{
  contract_version: contract_version(),
  surface_kind: surface_kind(),
  transport_options: map(),
  target_id: String.t() | nil,
  lease_ref: String.t() | nil,
  surface_ref: String.t() | nil,
  boundary_class: boundary_class(),
  observability: map()
}
```

# `reserved_key`

```elixir
@type reserved_key() ::
  :contract_version
  | :surface_kind
  | :transport_options
  | :target_id
  | :lease_ref
  | :surface_ref
  | :boundary_class
  | :observability
```

# `resolution_error`

```elixir
@type resolution_error() :: {:unsupported_surface_kind, surface_kind()}
```

# `resolved`

```elixir
@type resolved() :: %{
  adapter_capabilities:
    ExecutionPlane.Process.Transport.Surface.Capabilities.t(),
  dispatch: dispatch(),
  adapter_options: keyword(),
  surface: t()
}
```

# `surface_kind`

```elixir
@type surface_kind() :: :local_subprocess | :ssh_exec | :guest_bridge
```

# `t`

```elixir
@type t() :: %ExecutionPlane.Process.Transport.Surface{
  boundary_class: boundary_class(),
  contract_version: contract_version(),
  lease_ref: String.t() | nil,
  observability: map(),
  surface_kind: surface_kind(),
  surface_ref: String.t() | nil,
  target_id: String.t() | nil,
  transport_options: keyword()
}
```

# `validation_error`

```elixir
@type validation_error() ::
  {:invalid_contract_version, term()}
  | {:invalid_surface_kind, term()}
  | {:invalid_transport_options, term()}
  | {:invalid_execution_surface, term()}
  | {:invalid_target_id, term()}
  | {:invalid_lease_ref, term()}
  | {:invalid_surface_ref, term()}
  | {:invalid_boundary_class, term()}
  | {:invalid_observability, term()}
  | {:adapter_not_loaded, module()}
```

# `capabilities`

```elixir
@spec capabilities(t() | surface_kind() | keyword() | map() | nil) ::
  {:ok, ExecutionPlane.Process.Transport.Surface.Capabilities.t()}
  | {:error, term()}
```

# `contract_version`

```elixir
@spec contract_version() :: String.t()
```

# `default_surface_kind`

```elixir
@spec default_surface_kind() :: :local_subprocess
```

# `new`

```elixir
@spec new(keyword()) :: {:ok, t()} | {:error, validation_error()}
```

# `nonlocal_path_surface?`

```elixir
@spec nonlocal_path_surface?(t() | surface_kind() | keyword() | map() | nil) ::
  boolean()
```

# `normalize_surface_kind`

```elixir
@spec normalize_surface_kind(term()) ::
  {:ok, surface_kind()} | {:error, {:invalid_surface_kind, term()}}
```

# `normalize_transport_options`

```elixir
@spec normalize_transport_options(term()) ::
  {:ok, keyword()} | {:error, {:invalid_transport_options, term()}}
```

# `path_semantics`

```elixir
@spec path_semantics(t() | surface_kind() | keyword() | map() | nil) ::
  ExecutionPlane.Process.Transport.Surface.Capabilities.path_semantics() | nil
```

# `remote_surface?`

```elixir
@spec remote_surface?(t() | surface_kind() | keyword() | map() | nil) :: boolean()
```

# `remote_surface_kind?`

```elixir
@spec remote_surface_kind?(surface_kind()) :: boolean()
```

# `reserved_keys`

```elixir
@spec reserved_keys() :: [reserved_key(), ...]
```

# `resolve`

```elixir
@spec resolve(keyword()) ::
  {:ok, resolved()} | {:error, validation_error() | resolution_error()}
```

# `supported_surface_kinds`

```elixir
@spec supported_surface_kinds() :: [adapter_surface_kind(), ...]
```

# `surface_metadata`

```elixir
@spec surface_metadata(t()) :: keyword()
```

# `to_map`

```elixir
@spec to_map(t()) :: projected_t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
