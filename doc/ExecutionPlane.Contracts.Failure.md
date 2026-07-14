# `ExecutionPlane.Contracts.Failure`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/failure.ex#L1)

Structured failure payload used by `ExecutionOutcome.v1`.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.Failure{
  details: map(),
  durable_truth_relevance: :durable_truth | :raw_fact_only,
  failure_class: ExecutionPlane.Contracts.FailureClass.failure_class(),
  primary_owner: atom(),
  reason: String.t() | nil,
  retryable?: boolean()
}
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
