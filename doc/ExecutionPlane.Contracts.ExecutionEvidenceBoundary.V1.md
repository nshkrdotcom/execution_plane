# `ExecutionPlane.Contracts.ExecutionEvidenceBoundary.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/execution_evidence_boundary/v1.ex#L1)

Bounded report boundary for `ExecutionOutcome.v1`.

The raw payload remains owned by `ExecutionOutcome.v1`. This contract only
carries shapes, refs, and scan results that are safe to persist in evidence
reports.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.ExecutionEvidenceBoundary.V1{
  bounded_exit_code_or_response_shape: map(),
  bounded_status: String.t(),
  claim_check_ref_or_null: String.t() | nil,
  contract_version: String.t(),
  input_fingerprint_ref: String.t(),
  outcome_ref: String.t(),
  owner_repo: String.t(),
  persistence_posture: map() | nil,
  redacted_preview_ref_or_null: String.t() | nil,
  scan_result: map(),
  schema_ref: String.t()
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

# `scan_result`

```elixir
@spec scan_result(String.t()) :: map()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
