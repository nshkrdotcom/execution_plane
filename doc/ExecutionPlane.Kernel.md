# `ExecutionPlane.Kernel`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/kernel.ex#L1)

Minimal execution kernel for contract validation, dispatch, timeout
coordination, and raw-fact emission.

# `build_dispatch`

```elixir
@spec build_dispatch(
  struct() | map() | keyword(),
  ExecutionPlane.Contracts.ExecutionRoute.V1.t() | map() | keyword(),
  keyword()
) :: {:ok, ExecutionPlane.Kernel.DispatchPlan.t()} | {:error, Exception.t()}
```

# `build_dispatch!`

```elixir
@spec build_dispatch!(
  struct() | map() | keyword(),
  ExecutionPlane.Contracts.ExecutionRoute.V1.t() | map() | keyword(),
  keyword()
) :: ExecutionPlane.Kernel.DispatchPlan.t()
```

# `execute`

```elixir
@spec execute(
  struct() | map() | keyword(),
  ExecutionPlane.Contracts.ExecutionRoute.V1.t() | map() | keyword(),
  keyword()
) ::
  {:ok, ExecutionPlane.Kernel.ExecutionResult.t()}
  | {:error, ExecutionPlane.Kernel.ExecutionResult.t()}
```

# `protocol_module_for`

```elixir
@spec protocol_module_for(String.t()) :: module() | nil
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
