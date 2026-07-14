# `ExecutionPlane.Contracts`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts.ex#L1)

Canonical helpers for the Execution Plane contract packet.

Wave 1 freezes the contract names, versions, lineage keys, and failure
taxonomy. Family-specific payload interiors stay intentionally narrow and
provisional until Wave 3 prove-out.

# `handoff_status`

```elixir
@type handoff_status() :: :accepted | :rejected | :unknown
```

# `lineage_key`

```elixir
@type lineage_key() ::
  :tenant_id
  | :trace_id
  | :request_id
  | :decision_id
  | :boundary_session_id
  | :attempt_ref
  | :route_id
  | :event_id
  | :idempotency_key
```

# `lineage_t`

```elixir
@type lineage_t() :: %{
  optional(lineage_key()) =&gt; String.t(),
  optional(:extensions) =&gt; map()
}
```

# `local_spool_mode`

```elixir
@type local_spool_mode() :: :disabled | :emergency_only
```

# `canonical_lineage_keys`

```elixir
@spec canonical_lineage_keys() :: [lineage_key(), ...]
```

# `contract_modules`

```elixir
@spec contract_modules() :: [module(), ...]
```

# `contract_version!`

```elixir
@spec contract_version!(atom()) :: String.t()
```

# `contract_versions`

```elixir
@spec contract_versions() :: %{required(atom()) =&gt; String.t()}
```

# `dump_lineage`

```elixir
@spec dump_lineage(lineage_t()) :: map()
```

# `ensure_map!`

```elixir
@spec ensure_map!(term(), String.t()) :: map()
```

# `failure_classes`

```elixir
@spec failure_classes() :: [
  ExecutionPlane.Contracts.FailureClass.failure_class(),
  ...
]
```

# `fetch_optional_boolean!`

```elixir
@spec fetch_optional_boolean!(map() | keyword(), atom(), boolean()) :: boolean()
```

# `fetch_optional_list!`

```elixir
@spec fetch_optional_list!(map() | keyword(), atom(), [term()], (term() -&gt; term())) ::
  [term()]
```

# `fetch_optional_map!`

```elixir
@spec fetch_optional_map!(map() | keyword(), atom(), map()) :: map()
```

# `fetch_optional_stringish!`

```elixir
@spec fetch_optional_stringish!(map() | keyword(), atom(), String.t() | nil) ::
  String.t() | nil
```

# `fetch_required_actor_refs!`

```elixir
@spec fetch_required_actor_refs!(map() | keyword()) ::
  {String.t() | nil, String.t() | nil}
```

# `fetch_required_list!`

```elixir
@spec fetch_required_list!(map() | keyword(), atom(), (term() -&gt; term())) :: [term()]
```

# `fetch_required_map!`

```elixir
@spec fetch_required_map!(map() | keyword(), atom()) :: map()
```

# `fetch_required_non_neg_integer!`

```elixir
@spec fetch_required_non_neg_integer!(map() | keyword(), atom()) :: non_neg_integer()
```

# `fetch_required_stringish!`

```elixir
@spec fetch_required_stringish!(map() | keyword(), atom()) :: String.t()
```

# `fetch_value`

```elixir
@spec fetch_value(map() | keyword(), atom()) :: term()
```

# `handoff_receipt_id`

```elixir
@spec handoff_receipt_id(String.t(), String.t()) :: String.t()
```

# `handoff_statuses`

```elixir
@spec handoff_statuses() :: [handoff_status(), ...]
```

# `lane_churn_fact_id`

```elixir
@spec lane_churn_fact_id(String.t(), String.t(), non_neg_integer()) :: String.t()
```

# `local_spool_modes`

```elixir
@spec local_spool_modes() :: [local_spool_mode(), ...]
```

# `maybe_match_lineage!`

```elixir
@spec maybe_match_lineage!(String.t(), lineage_t(), lineage_key(), String.t()) :: :ok
```

# `normalize_attrs`

```elixir
@spec normalize_attrs(map() | keyword()) :: map()
```

# `normalize_extensions!`

```elixir
@spec normalize_extensions!(map() | keyword()) :: map()
```

# `normalize_lineage!`

```elixir
@spec normalize_lineage!(map() | keyword(), [lineage_key()]) :: lineage_t()
```

# `pressure_fact_id`

```elixir
@spec pressure_fact_id(String.t(), String.t(), non_neg_integer()) :: String.t()
```

# `reconnect_fact_id`

```elixir
@spec reconnect_fact_id(String.t(), String.t(), non_neg_integer()) :: String.t()
```

# `stringify_keys`

```elixir
@spec stringify_keys(term()) :: term()
```

# `validate_contract_version!`

```elixir
@spec validate_contract_version!(map() | keyword(), String.t()) :: String.t()
```

# `validate_iso8601!`

```elixir
@spec validate_iso8601!(atom() | String.t(), String.t()) :: String.t()
```

# `validate_non_empty_string!`

```elixir
@spec validate_non_empty_string!(term(), String.t()) :: String.t()
```

# `validate_opaque_handle_ref!`

```elixir
@spec validate_opaque_handle_ref!(atom() | String.t(), String.t()) :: String.t()
```

# `validate_string!`

```elixir
@spec validate_string!(term(), String.t()) :: String.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
