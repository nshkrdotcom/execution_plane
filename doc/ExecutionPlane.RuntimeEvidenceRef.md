# `ExecutionPlane.RuntimeEvidenceRef`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/enterprise_precut_metadata.ex#L245)

Public-safe reference to raw runtime evidence.

# `t`

```elixir
@type t() :: %ExecutionPlane.RuntimeEvidenceRef{
  contract_name: term(),
  lower_run_ref: term(),
  payload_hash: term(),
  redaction_posture: term(),
  resource_ref: term(),
  runtime_evidence_ref: term(),
  tenant_ref: term(),
  trace_id: term()
}
```

# `new`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
