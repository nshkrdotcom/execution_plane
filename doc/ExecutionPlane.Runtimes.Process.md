# `ExecutionPlane.Runtimes.Process`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/runtimes/process.ex#L1)

Minimal process runtime for one-shot local execution in the execution-plane
substrate.

# `execute`

```elixir
@spec execute(
  ExecutionPlane.Kernel.DispatchPlan.t(),
  keyword()
) :: {:ok, map()} | {:error, map()}
```

# `family`

```elixir
@spec family() :: String.t()
```

# `run`

```elixir
@spec run(keyword()) ::
  {:ok, ExecutionPlane.Runtimes.Process.RunResult.t()} | {:error, term()}
```

# `supports_intent?`

```elixir
@spec supports_intent?(struct() | map() | keyword()) :: boolean()
```

# `supports_surface?`

```elixir
@spec supports_surface?(ExecutionPlane.Placements.Surface.t() | nil) :: boolean()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
