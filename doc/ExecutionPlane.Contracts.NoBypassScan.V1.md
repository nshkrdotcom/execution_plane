# `ExecutionPlane.Contracts.NoBypassScan.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/no_bypass_scan/v1.ex#L1)

Source-boundary proof that hazmat Execution Plane APIs are not imported by public code.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.NoBypassScan.V1{
  authority_packet_ref: term(),
  caller_repo: term(),
  checked_paths: term(),
  contract_version: term(),
  correlation_id: term(),
  environment_ref: term(),
  forbidden_module: term(),
  idempotency_key: term(),
  installation_ref: term(),
  permission_decision_ref: term(),
  principal_ref: term(),
  project_ref: term(),
  release_manifest_ref: term(),
  required_facade: term(),
  resource_ref: term(),
  scan_ref: term(),
  scan_status: term(),
  system_actor_ref: term(),
  tenant_ref: term(),
  trace_id: term(),
  violation_ref: term(),
  violations: term(),
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
