# `ExecutionPlane.Contracts.PersistencePosture`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/persistence_posture.ex#L1)

Ref-only persistence posture for lower target and attach surfaces.

Persistence posture is storage evidence only. It does not grant target attach
authority and it never persists raw process state.

# `t`

```elixir
@type t() :: map()
```

# `components`

```elixir
@spec components() :: [atom()]
```

# `durable?`

```elixir
@spec durable?(t()) :: boolean()
```

# `durable_capability`

```elixir
@spec durable_capability(atom(), atom()) ::
  GroundPlane.PersistencePolicy.StoreCapability.t()
```

# `memory`

```elixir
@spec memory(atom()) :: t()
```

# `memory_capability`

```elixir
@spec memory_capability(atom()) :: GroundPlane.PersistencePolicy.StoreCapability.t()
```

# `preflight`

```elixir
@spec preflight(atom(), map() | keyword(), [
  GroundPlane.PersistencePolicy.StoreCapability.t()
]) ::
  :ok | {:error, term()}
```

# `resolve`

```elixir
@spec resolve(atom(), map() | keyword()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
