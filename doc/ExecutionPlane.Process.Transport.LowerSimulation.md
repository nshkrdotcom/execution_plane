# `ExecutionPlane.Process.Transport.LowerSimulation`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/lower_simulation.ex#L1)

Execution Plane-owned process transport simulation surface.

The adapter replays configured stdout/stderr/exit frames through the normal
process transport contract. It never spawns a process and is intended to be
selected by higher-layer configuration, not by public request keywords.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `run`

```elixir
@spec run(
  ExecutionPlane.Command.t(),
  keyword()
) ::
  {:ok, ExecutionPlane.Process.Transport.RunResult.t()}
  | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

# `start`

```elixir
@spec start(keyword()) ::
  {:ok, pid()}
  | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

# `start_link`

```elixir
@spec start_link(keyword()) ::
  {:ok, pid()}
  | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
