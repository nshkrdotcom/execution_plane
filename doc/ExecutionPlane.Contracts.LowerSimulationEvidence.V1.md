# `ExecutionPlane.Contracts.LowerSimulationEvidence.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/lower_simulation_evidence/v1.ex#L1)

Bounded evidence that a lower-runtime simulation scenario produced an
`ExecutionOutcome.v1` without external side effects.

The raw lower-family payload remains in `ExecutionOutcome.v1.raw_payload`.
This wrapper records only hashes, shapes, and side-effect policy facts so
evidence consumers do not need to reinterpret or narrow the v1 raw payload.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.LowerSimulationEvidence.V1{
  contract_version: String.t(),
  family: String.t(),
  input_fingerprint: map(),
  lineage: ExecutionPlane.Contracts.lineage_t(),
  outcome_contract_version: String.t(),
  outcome_family: String.t(),
  outcome_status: String.t(),
  output_fingerprint: map(),
  protocol: String.t(),
  raw_payload_shape: [String.t()],
  route_id: String.t(),
  scenario_ref: String.t(),
  side_effect_policy: String.t(),
  side_effect_result: String.t()
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
