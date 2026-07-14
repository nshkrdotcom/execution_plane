# `ExecutionPlane.Contracts.FailureClass`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/failure_class.ex#L1)

Typed failure-class enum for the shared contract packet.

# `failure_class`

```elixir
@type failure_class() ::
  :policy_denied
  | :route_unresolved
  | :placement_unavailable
  | :launch_failed
  | :transport_failed
  | :protocol_framing_failed
  | :semantic_runtime_failed
  | :approval_expired
  | :lease_expired
  | :attach_mismatch
  | :remote_disconnect
  | :cancellation
  | :timeout
```

# `metadata_t`

```elixir
@type metadata_t() :: %{
  primary_owner: atom(),
  retryable?: boolean(),
  durable_truth_relevance: :durable_truth | :raw_fact_only
}
```

# `metadata`

```elixir
@spec metadata(failure_class()) :: metadata_t()
```

# `normalize!`

```elixir
@spec normalize!(failure_class() | String.t()) :: failure_class()
```

# `valid?`

```elixir
@spec valid?(failure_class()) :: boolean()
```

# `values`

```elixir
@spec values() :: [failure_class(), ...]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
