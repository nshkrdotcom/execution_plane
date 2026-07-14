# `ExecutionPlane.Kernel.ExecutionResult`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/kernel/execution_result.ex#L1)

Result bundle returned by the minimal execution-plane kernel.

# `t`

```elixir
@type t() :: %ExecutionPlane.Kernel.ExecutionResult{
  events: [ExecutionPlane.Contracts.ExecutionEvent.V1.t()],
  outcome: ExecutionPlane.Contracts.ExecutionOutcome.V1.t(),
  plan: ExecutionPlane.Kernel.DispatchPlan.t()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
