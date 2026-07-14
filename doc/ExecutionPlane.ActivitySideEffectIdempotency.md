# `ExecutionPlane.ActivitySideEffectIdempotency`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/enterprise_precut_metadata.ex#L283)

Activity-facing side-effect idempotency contract for Phase 4 durable workflows.

Mezzanine owns workflow worker execution. Execution Plane owns the lower
runtime side effect and dedupes retries by execution intent id and idempotency
key.

# `t`

```elixir
@type t() :: %ExecutionPlane.ActivitySideEffectIdempotency{
  activity_call_ref: term(),
  actor_ref: term(),
  authority_packet_ref: term(),
  contract_name: term(),
  heartbeat_policy: term(),
  idempotency_key: term(),
  intent_id: term(),
  lease_evidence_ref: term(),
  lease_ref: term(),
  lower_run_ref: term(),
  permission_decision_ref: term(),
  release_manifest_ref: term(),
  resource_ref: term(),
  retry_policy: term(),
  runtime_family: term(),
  side_effect_ref: term(),
  tenant_ref: term(),
  timeout_policy: term(),
  trace_id: term(),
  workflow_ref: term()
}
```

# `contract_name`

```elixir
@spec contract_name() :: String.t()
```

# `idempotency_scope`

```elixir
@spec idempotency_scope() :: String.t()
```

# `new`

```elixir
@spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
```

# `same_retry_scope?`

```elixir
@spec same_retry_scope?(t(), t()) :: boolean()
```

# `side_effect_key`

```elixir
@spec side_effect_key(t()) :: {String.t(), String.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
