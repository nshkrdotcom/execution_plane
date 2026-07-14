# `ExecutionPlane.CancellationMetadata`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/enterprise_precut_metadata.ex#L84)

Cancellation metadata linked to authority, workflow, and lower run refs.

# `t`

```elixir
@type t() :: %ExecutionPlane.CancellationMetadata{
  activity_call_ref: term(),
  actor_ref: term(),
  authority_packet_ref: term(),
  cancellation_id: term(),
  contract_name: term(),
  idempotency_key: term(),
  lower_run_ref: term(),
  permission_decision_ref: term(),
  resource_ref: term(),
  tenant_ref: term(),
  trace_id: term(),
  workflow_ref: term()
}
```

# `new`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
