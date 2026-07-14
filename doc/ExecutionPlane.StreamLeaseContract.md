# `ExecutionPlane.StreamLeaseContract`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/enterprise_precut_metadata.ex#L215)

Stream lease and revocation metadata contract.

# `t`

```elixir
@type t() :: %ExecutionPlane.StreamLeaseContract{
  contract_name: term(),
  epoch_ref: term(),
  lease_ref: term(),
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
