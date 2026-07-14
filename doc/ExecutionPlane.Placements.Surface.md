# `ExecutionPlane.Placements.Surface`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/placements/surface.ex#L1)

Narrow execution-surface contract for process placement and runtime routing.

# `t`

```elixir
@type t() :: %ExecutionPlane.Placements.Surface{
  boundary_class: String.t() | atom() | nil,
  contract_version: String.t(),
  lease_ref: String.t() | nil,
  observability: map(),
  surface_kind: String.t(),
  surface_ref: String.t() | nil,
  target_id: String.t() | nil,
  transport_options: map()
}
```

# `capabilities`

```elixir
@spec capabilities(String.t() | atom() | map() | keyword() | t() | nil) ::
  {:ok, ExecutionPlane.Placements.Capabilities.t()} | {:error, term()}
```

# `contract_version`

```elixir
@spec contract_version() :: String.t()
```

# `new`

```elixir
@spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, term()}
```

# `new!`

```elixir
@spec new!(map() | keyword() | t()) :: t()
```

# `nonlocal_path_surface?`

```elixir
@spec nonlocal_path_surface?(String.t() | atom() | map() | keyword() | t() | nil) ::
  boolean()
```

# `path_semantics`

```elixir
@spec path_semantics(String.t() | atom() | map() | keyword() | t() | nil) ::
  :local | :remote | :guest | nil
```

# `placement_family`

```elixir
@spec placement_family(String.t() | atom() | map() | keyword() | t() | nil) ::
  String.t() | nil
```

# `remote_surface?`

```elixir
@spec remote_surface?(String.t() | atom() | map() | keyword() | t() | nil) ::
  boolean()
```

# `supported_surface_kinds`

```elixir
@spec supported_surface_kinds() :: [String.t(), ...]
```

# `to_map`

```elixir
@spec to_map(t()) :: map()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
