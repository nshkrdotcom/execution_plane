# `ExecutionPlane.Contracts.WorkerBudget.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/worker_budget/v1.ex#L1)

Worker admission and pressure-shedding evidence for tenant-scoped budgets.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.WorkerBudget.V1{
  admission_decision_ref: term(),
  authority_packet_ref: term(),
  budget_ref: term(),
  contract_version: term(),
  correlation_id: term(),
  current_load: term(),
  environment_ref: term(),
  idempotency_key: term(),
  installation_ref: term(),
  permission_decision_ref: term(),
  principal_ref: term(),
  project_ref: term(),
  queue_ref: term(),
  release_manifest_ref: term(),
  resource_ref: term(),
  shed_reason: term(),
  system_actor_ref: term(),
  tenant_ref: term(),
  trace_id: term(),
  worker_pool_ref: term(),
  workspace_ref: term()
}
```

# `contract_version`

```elixir
@spec contract_version() :: String.t()
```

# `dump`

```elixir
@spec dump(t()) :: map()
```

# `new`

```elixir
@spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
```

# `new!`

```elixir
@spec new!(map() | keyword() | t()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
