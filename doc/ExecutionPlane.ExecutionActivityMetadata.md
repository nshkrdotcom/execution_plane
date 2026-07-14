# `ExecutionPlane.ExecutionActivityMetadata`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/enterprise_precut_metadata.ex#L32)

Execution activity metadata consumed by Mezzanine activities.

# `t`

```elixir
@type t() :: %ExecutionPlane.ExecutionActivityMetadata{
  activity_call_ref: term(),
  actor_ref: term(),
  authority_packet_ref: term(),
  contract_name: term(),
  heartbeat_policy: term(),
  idempotency_key: term(),
  lower_run_ref: term(),
  permission_decision_ref: term(),
  resource_ref: term(),
  runtime_family: term(),
  target_ref: term(),
  tenant_ref: term(),
  timeout_policy: term(),
  trace_id: term(),
  workflow_ref: term()
}
```

# `new`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
