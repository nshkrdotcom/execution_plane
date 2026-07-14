# `ExecutionPlane.Process`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process.ex#L1)

Helper surface for one-shot subprocess execution.

This helper emits `ProcessExecutionIntent.v1`, resolves the minimal local
process route, and executes through the kernel without requiring callers to
hand-assemble contracts.

# `run`

```elixir
@spec run(
  map() | keyword(),
  keyword()
) ::
  {:ok, ExecutionPlane.Kernel.ExecutionResult.t()}
  | {:error, ExecutionPlane.Kernel.ExecutionResult.t()}
@spec run(
  String.t(),
  keyword()
) ::
  {:ok, ExecutionPlane.Kernel.ExecutionResult.t()}
  | {:error, ExecutionPlane.Kernel.ExecutionResult.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
