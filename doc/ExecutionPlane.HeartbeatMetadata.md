# `ExecutionPlane.HeartbeatMetadata`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/enterprise_precut_metadata.ex#L129)

Heartbeat metadata linked to workflow activity and lease evidence.

# `t`

```elixir
@type t() :: %ExecutionPlane.HeartbeatMetadata{
  activity_call_ref: term(),
  contract_name: term(),
  heartbeat_id: term(),
  lease_ref: term(),
  lower_run_ref: term(),
  resource_ref: term(),
  tenant_ref: term(),
  trace_id: term(),
  workflow_ref: term()
}
```

# `new`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
