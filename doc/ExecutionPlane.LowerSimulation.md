# `ExecutionPlane.LowerSimulation`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/lower_simulation.ex#L1)

Route-configured lower-runtime simulation support.

This module is deliberately lower-only: it consumes a resolved route target
descriptor and emits normal lower-family raw payloads plus bounded evidence
artifacts. Callers do not pass a public `simulation:` option.

# `simulation_result`

```elixir
@type simulation_result() :: :not_configured | {:ok, map()} | {:error, map()}
```

# `execute_if_configured`

```elixir
@spec execute_if_configured(
  String.t(),
  struct(),
  ExecutionPlane.Contracts.ExecutionRoute.V1.t(),
  integer()
) :: simulation_result()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
