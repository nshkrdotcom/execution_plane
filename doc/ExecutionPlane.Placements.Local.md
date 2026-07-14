# `ExecutionPlane.Placements.Local`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/placements/local.ex#L1)

Same-node placement semantics for the execution-plane substrate.

# `placement_family`

```elixir
@spec placement_family() :: String.t()
```

# `supported_surface_kinds`

```elixir
@spec supported_surface_kinds() :: [String.t(), ...]
```

# `supports_surface?`

```elixir
@spec supports_surface?(
  ExecutionPlane.Placements.Surface.t()
  | map()
  | keyword()
  | String.t()
  | atom()
) ::
  boolean()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
