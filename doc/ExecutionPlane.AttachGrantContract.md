# `ExecutionPlane.AttachGrantContract`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/enterprise_precut_metadata.ex#L169)

Lease-bound attach grant contract.

# `t`

```elixir
@type t() :: %ExecutionPlane.AttachGrantContract{
  attach_grant_id: term(),
  authority_packet_ref: term(),
  contract_name: term(),
  expires_at: term(),
  lease_ref: term(),
  permission_decision_ref: term(),
  principal_ref: term(),
  resource_ref: term(),
  revocation_state: term(),
  stream_ref: term(),
  tenant_ref: term(),
  trace_id: term()
}
```

# `new`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
