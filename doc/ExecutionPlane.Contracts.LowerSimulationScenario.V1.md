# `ExecutionPlane.Contracts.LowerSimulationScenario.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/lower_simulation_scenario/v1.ex#L1)

Phase 6 lower-runtime scenario contract owned by Execution Plane.

This contract describes deterministic lower behavior and bounded evidence
projection. It deliberately rejects semantic provider/model/budget policy and
does not reinterpret `ExecutionOutcome.v1.raw_payload`.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.LowerSimulationScenario.V1{
  bounded_evidence_projection: map(),
  cleanup_behavior: map(),
  contract_version: String.t(),
  input_fingerprint_ref: String.t(),
  matcher_class: String.t(),
  no_egress_assertion: map(),
  owner_repo: String.t(),
  protocol_surface: String.t(),
  route_kind: String.t(),
  scenario_id: String.t(),
  status_or_exit_or_response_or_stream_or_chunk_or_fault_shape: map(),
  version: String.t()
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
