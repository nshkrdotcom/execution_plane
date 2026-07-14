# `ExecutionPlane.Kernel.DispatchPlan`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/kernel/dispatch_plan.ex#L1)

Minimal Wave 1 dispatch plan produced from a validated route and lower intent.

# `t`

```elixir
@type t() :: %ExecutionPlane.Kernel.DispatchPlan{
  family: String.t(),
  intent: struct(),
  placement_surface: struct() | nil,
  protocol: String.t(),
  protocol_module: module(),
  route: struct(),
  route_id: String.t(),
  timeout_ms: pos_integer()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
