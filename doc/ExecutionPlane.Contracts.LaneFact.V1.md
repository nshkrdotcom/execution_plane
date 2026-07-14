# `ExecutionPlane.Contracts.LaneFact.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/lane_fact/v1.ex#L1)

Neutral bounded lower-lane fact.

`LaneFact.v1` is the safe shape handed upward from Execution Plane lanes. Raw
stdout, stderr, HTTP bodies, workflow histories, credentials, and product
workflow decisions remain outside this contract.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.LaneFact.V1{
  contract_version: String.t(),
  evidence_refs: [String.t()],
  fact_ref: String.t(),
  family: String.t(),
  lane_id: String.t(),
  lineage: ExecutionPlane.Contracts.lineage_t(),
  max_output_bytes: pos_integer(),
  output_byte_size: non_neg_integer(),
  output_hash_ref: String.t(),
  output_ref: String.t() | nil,
  payload_shape: map(),
  phase: String.t(),
  protocol: String.t(),
  redacted_preview_ref: String.t() | nil,
  route_id: String.t(),
  sequence: non_neg_integer(),
  timestamp: String.t(),
  transport_ref: String.t()
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

# `from_event!`

```elixir
@spec from_event!(
  ExecutionPlane.Contracts.ExecutionEvent.V1.t(),
  keyword()
) :: t()
```

# `from_outcome!`

```elixir
@spec from_outcome!(
  ExecutionPlane.Contracts.ExecutionOutcome.V1.t(),
  keyword()
) :: t()
```

# `new`

```elixir
@spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
```

# `new!`

```elixir
@spec new!(map() | keyword() | t()) :: t()
```

# `phases`

```elixir
@spec phases() :: [String.t(), ...]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
