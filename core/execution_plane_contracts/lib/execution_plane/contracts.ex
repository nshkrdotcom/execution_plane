defmodule ExecutionPlane.Contracts do
  @moduledoc """
  Canonical helpers for the Execution Plane contract packet.

  Wave 1 freezes the contract names, versions, lineage keys, and failure
  taxonomy. Family-specific payload interiors stay intentionally narrow and
  provisional until Wave 3 prove-out.
  """

  alias ExecutionPlane.Contracts.FailureClass

  @contract_versions %{
    authority_decision_v1: "authority_decision.v1",
    boundary_session_descriptor_v1: "boundary_session_descriptor.v1",
    execution_intent_envelope_v1: "execution_intent_envelope.v1",
    http_execution_intent_v1: "http_execution_intent.v1",
    process_execution_intent_v1: "process_execution_intent.v1",
    jsonrpc_execution_intent_v1: "jsonrpc_execution_intent.v1",
    execution_route_v1: "execution_route.v1",
    attach_grant_v1: "ExecutionPlane.AttachGrant.v1",
    credential_handle_ref_v1: "credential_handle_ref.v1",
    execution_event_v1: "execution_event.v1",
    execution_outcome_v1: "execution_outcome.v1",
    lower_simulation_scenario_v1: "ExecutionPlane.LowerSimulationScenario.v1",
    lower_simulation_evidence_v1: "ExecutionPlane.LowerSimulationEvidence.v1",
    execution_evidence_boundary_v1: "ExecutionPlane.ExecutionEvidenceBoundary.v1",
    no_egress_policy_v1: "ExecutionPlane.NoEgressPolicy.v1",
    adapter_selection_policy_v1: "ExecutionPlane.AdapterSelectionPolicy.v1",
    stream_backpressure_v1: "ExecutionPlane.StreamBackpressure.v1",
    worker_budget_v1: "ExecutionPlane.WorkerBudget.v1",
    no_bypass_scan_v1: "ExecutionPlane.NoBypassScan.v1",
    stream_attach_revocation_v1: "ExecutionPlane.StreamAttachRevocation.v1"
  }

  @contract_modules [
    ExecutionPlane.Contracts.AuthorityDecision.V1,
    ExecutionPlane.Contracts.BoundarySessionDescriptor.V1,
    ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1,
    ExecutionPlane.Contracts.HttpExecutionIntent.V1,
    ExecutionPlane.Contracts.ProcessExecutionIntent.V1,
    ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1,
    ExecutionPlane.Contracts.ExecutionRoute.V1,
    ExecutionPlane.Contracts.AttachGrant.V1,
    ExecutionPlane.Contracts.CredentialHandleRef.V1,
    ExecutionPlane.Contracts.ExecutionEvent.V1,
    ExecutionPlane.Contracts.ExecutionOutcome.V1,
    ExecutionPlane.Contracts.LowerSimulationScenario.V1,
    ExecutionPlane.Contracts.LowerSimulationEvidence.V1,
    ExecutionPlane.Contracts.ExecutionEvidenceBoundary.V1,
    ExecutionPlane.Contracts.NoEgressPolicy.V1,
    ExecutionPlane.Contracts.AdapterSelectionPolicy.V1,
    ExecutionPlane.Contracts.StreamBackpressure.V1,
    ExecutionPlane.Contracts.WorkerBudget.V1,
    ExecutionPlane.Contracts.NoBypassScan.V1,
    ExecutionPlane.Contracts.StreamAttachRevocation.V1
  ]

  @canonical_lineage_keys [
    :tenant_id,
    :trace_id,
    :request_id,
    :decision_id,
    :boundary_session_id,
    :attempt_ref,
    :route_id,
    :event_id,
    :idempotency_key
  ]
  @handoff_statuses [:accepted, :rejected, :unknown]
  @local_spool_modes [:disabled, :emergency_only]

  @type lineage_key ::
          :tenant_id
          | :trace_id
          | :request_id
          | :decision_id
          | :boundary_session_id
          | :attempt_ref
          | :route_id
          | :event_id
          | :idempotency_key

  @type lineage_t :: %{optional(lineage_key()) => String.t(), optional(:extensions) => map()}
  @type handoff_status :: :accepted | :rejected | :unknown
  @type local_spool_mode :: :disabled | :emergency_only

  @spec contract_versions() :: %{required(atom()) => String.t()}
  def contract_versions, do: @contract_versions

  @spec contract_modules() :: [module(), ...]
  def contract_modules do
    Enum.each(@contract_modules, &Code.ensure_loaded!/1)
    @contract_modules
  end

  @spec contract_version!(atom()) :: String.t()
  def contract_version!(key), do: Map.fetch!(@contract_versions, key)

  @spec canonical_lineage_keys() :: [lineage_key(), ...]
  def canonical_lineage_keys, do: @canonical_lineage_keys

  @spec handoff_statuses() :: [handoff_status(), ...]
  def handoff_statuses, do: @handoff_statuses

  @spec local_spool_modes() :: [local_spool_mode(), ...]
  def local_spool_modes, do: @local_spool_modes

  @spec handoff_receipt_id(String.t(), String.t()) :: String.t()
  def handoff_receipt_id(route_id, handoff_ref)
      when is_binary(route_id) and is_binary(handoff_ref) do
    route_id = validate_non_empty_string!(route_id, "handoff_receipt.route_id")
    handoff_ref = validate_non_empty_string!(handoff_ref, "handoff_receipt.handoff_ref")

    "receipt:#{route_id}:#{handoff_ref}"
  end

  @spec pressure_fact_id(String.t(), String.t(), non_neg_integer()) :: String.t()
  def pressure_fact_id(route_id, lane_ref, seq)
      when is_binary(route_id) and is_binary(lane_ref) and is_integer(seq) and seq >= 0 do
    fact_id("pressure", route_id, lane_ref, seq)
  end

  @spec reconnect_fact_id(String.t(), String.t(), non_neg_integer()) :: String.t()
  def reconnect_fact_id(route_id, lane_ref, seq)
      when is_binary(route_id) and is_binary(lane_ref) and is_integer(seq) and seq >= 0 do
    fact_id("reconnect", route_id, lane_ref, seq)
  end

  @spec lane_churn_fact_id(String.t(), String.t(), non_neg_integer()) :: String.t()
  def lane_churn_fact_id(route_id, lane_ref, seq)
      when is_binary(route_id) and is_binary(lane_ref) and is_integer(seq) and seq >= 0 do
    fact_id("lane_churn", route_id, lane_ref, seq)
  end

  @spec failure_classes() :: [FailureClass.failure_class(), ...]
  def failure_classes, do: FailureClass.values()

  @spec normalize_attrs(map() | keyword()) :: map()
  def normalize_attrs(attrs) when is_map(attrs), do: attrs

  def normalize_attrs(attrs) when is_list(attrs) do
    if Keyword.keyword?(attrs) do
      Map.new(attrs)
    else
      raise ArgumentError, "expected keyword attrs, got: #{inspect(attrs)}"
    end
  end

  def normalize_attrs(attrs) do
    raise ArgumentError, "expected map or keyword attrs, got: #{inspect(attrs)}"
  end

  @spec fetch_value(map() | keyword(), atom()) :: term()
  def fetch_value(attrs, key) do
    attrs = normalize_attrs(attrs)
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
  end

  @spec fetch_required_stringish!(map() | keyword(), atom()) :: String.t()
  def fetch_required_stringish!(attrs, key) do
    attrs
    |> fetch_value(key)
    |> validate_non_empty_string!(to_string(key))
  end

  @spec fetch_optional_stringish!(map() | keyword(), atom(), String.t() | nil) :: String.t() | nil
  def fetch_optional_stringish!(attrs, key, default \\ nil) do
    case fetch_value(attrs, key) do
      nil -> default
      value -> validate_non_empty_string!(value, to_string(key))
    end
  end

  @spec fetch_required_map!(map() | keyword(), atom()) :: map()
  def fetch_required_map!(attrs, key) do
    attrs
    |> fetch_value(key)
    |> ensure_map!(to_string(key))
  end

  @spec fetch_optional_map!(map() | keyword(), atom(), map()) :: map()
  def fetch_optional_map!(attrs, key, default \\ %{}) do
    case fetch_value(attrs, key) do
      nil -> default
      value -> ensure_map!(value, to_string(key))
    end
  end

  @spec fetch_required_list!(map() | keyword(), atom(), (term() -> term())) :: [term()]
  def fetch_required_list!(attrs, key, validator \\ & &1) do
    case fetch_value(attrs, key) do
      values when is_list(values) -> Enum.map(values, validator)
      other -> raise ArgumentError, "#{key} must be a list, got: #{inspect(other)}"
    end
  end

  @spec fetch_optional_list!(map() | keyword(), atom(), [term()], (term() -> term())) :: [term()]
  def fetch_optional_list!(attrs, key, default \\ [], validator \\ & &1) do
    case fetch_value(attrs, key) do
      nil -> default
      values when is_list(values) -> Enum.map(values, validator)
      other -> raise ArgumentError, "#{key} must be a list, got: #{inspect(other)}"
    end
  end

  @spec fetch_optional_boolean!(map() | keyword(), atom(), boolean()) :: boolean()
  def fetch_optional_boolean!(attrs, key, default \\ false) do
    case fetch_value(attrs, key) do
      nil -> default
      value when is_boolean(value) -> value
      other -> raise ArgumentError, "#{key} must be a boolean, got: #{inspect(other)}"
    end
  end

  @spec fetch_required_non_neg_integer!(map() | keyword(), atom()) :: non_neg_integer()
  def fetch_required_non_neg_integer!(attrs, key) do
    case fetch_value(attrs, key) do
      value when is_integer(value) and value >= 0 ->
        value

      other ->
        raise ArgumentError, "#{key} must be a non-negative integer, got: #{inspect(other)}"
    end
  end

  @spec fetch_required_actor_refs!(map() | keyword()) :: {String.t() | nil, String.t() | nil}
  def fetch_required_actor_refs!(attrs) do
    principal_ref = fetch_optional_stringish!(attrs, :principal_ref)
    system_actor_ref = fetch_optional_stringish!(attrs, :system_actor_ref)

    if is_nil(principal_ref) and is_nil(system_actor_ref) do
      raise ArgumentError, "principal_ref or system_actor_ref is required"
    end

    {principal_ref, system_actor_ref}
  end

  @spec validate_contract_version!(map() | keyword(), String.t()) :: String.t()
  def validate_contract_version!(attrs, expected_version) do
    version = fetch_optional_stringish!(attrs, :contract_version, expected_version)

    if version == expected_version do
      version
    else
      raise ArgumentError,
            "expected contract_version #{inspect(expected_version)}, got: #{inspect(version)}"
    end
  end

  @spec normalize_extensions!(map() | keyword()) :: map()
  def normalize_extensions!(attrs), do: fetch_optional_map!(attrs, :extensions, %{})

  @spec normalize_lineage!(map() | keyword(), [lineage_key()]) :: lineage_t()
  def normalize_lineage!(lineage, required_keys \\ []) do
    lineage
    |> normalize_attrs()
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, normalize_lineage_key!(key), value)
    end)
    |> Enum.reduce(%{}, fn
      {:extensions, value}, acc ->
        Map.put(acc, :extensions, ensure_map!(value, "lineage.extensions"))

      {key, value}, acc ->
        Map.put(acc, key, validate_non_empty_string!(value, "lineage.#{key}"))
    end)
    |> maybe_backfill_trace_id(required_keys)
    |> then(fn normalized ->
      Enum.each(required_keys, fn key ->
        if is_nil(Map.get(normalized, key)) do
          raise ArgumentError, "lineage.#{key} is required"
        end
      end)

      normalized
    end)
  end

  @spec maybe_match_lineage!(String.t(), lineage_t(), lineage_key(), String.t()) :: :ok
  def maybe_match_lineage!(value, lineage, key, field_name) do
    case Map.get(lineage, key) do
      nil ->
        :ok

      ^value ->
        :ok

      other ->
        raise ArgumentError, "#{field_name} must match lineage.#{key}, got: #{inspect(other)}"
    end
  end

  @spec validate_non_empty_string!(term(), String.t()) :: String.t()
  def validate_non_empty_string!(value, _field_name)
      when is_binary(value) and byte_size(value) > 0,
      do: value

  def validate_non_empty_string!(nil, field_name) do
    raise ArgumentError, "#{field_name} must be a non-empty string, got: nil"
  end

  def validate_non_empty_string!(value, field_name) when is_atom(value),
    do: value |> Atom.to_string() |> validate_non_empty_string!(field_name)

  def validate_non_empty_string!(value, field_name) do
    raise ArgumentError, "#{field_name} must be a non-empty string, got: #{inspect(value)}"
  end

  @spec validate_string!(term(), String.t()) :: String.t()
  def validate_string!(value, _field_name) when is_binary(value), do: value

  def validate_string!(nil, field_name) do
    raise ArgumentError, "#{field_name} must be a string, got: nil"
  end

  def validate_string!(value, field_name) when is_atom(value),
    do: value |> Atom.to_string() |> validate_string!(field_name)

  def validate_string!(value, field_name) do
    raise ArgumentError, "#{field_name} must be a string, got: #{inspect(value)}"
  end

  @spec validate_opaque_handle_ref!(term(), String.t()) :: String.t()
  def validate_opaque_handle_ref!(value, field_name) do
    value = validate_non_empty_string!(value, field_name)

    if String.contains?(value, "://") or String.starts_with?(value, "urn:") do
      value
    else
      raise ArgumentError,
            "#{field_name} must be an opaque handle ref, got: #{inspect(value)}"
    end
  end

  @spec validate_iso8601!(term(), String.t()) :: String.t()
  def validate_iso8601!(value, field_name) do
    value = validate_non_empty_string!(value, field_name)

    case DateTime.from_iso8601(value) do
      {:ok, _datetime, _offset} ->
        value

      {:error, _reason} ->
        raise ArgumentError, "#{field_name} must be ISO8601, got: #{inspect(value)}"
    end
  end

  @spec ensure_map!(term(), String.t()) :: map()
  def ensure_map!(value, _field_name) when is_map(value), do: Map.new(value)

  def ensure_map!(value, field_name) do
    raise ArgumentError, "#{field_name} must be a map, got: #{inspect(value)}"
  end

  @spec stringify_keys(term()) :: term()
  def stringify_keys(%_{} = struct), do: struct

  def stringify_keys(value) when is_map(value) do
    Enum.into(value, %{}, fn {key, nested} -> {to_string(key), stringify_keys(nested)} end)
  end

  def stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  def stringify_keys(value), do: value

  @spec dump_lineage(lineage_t()) :: map()
  def dump_lineage(lineage) when is_map(lineage), do: stringify_keys(lineage)

  defp fact_id(kind, route_id, lane_ref, seq) do
    kind = validate_non_empty_string!(kind, "fact.kind")
    route_id = validate_non_empty_string!(route_id, "fact.route_id")
    lane_ref = validate_non_empty_string!(lane_ref, "fact.lane_ref")

    "#{kind}:#{route_id}:#{lane_ref}:#{seq}"
  end

  defp normalize_lineage_key!(key) when key in @canonical_lineage_keys, do: key
  defp normalize_lineage_key!(:extensions), do: :extensions

  defp normalize_lineage_key!(key) when is_binary(key) do
    case key do
      "tenant_id" -> :tenant_id
      "trace_id" -> :trace_id
      "request_id" -> :request_id
      "decision_id" -> :decision_id
      "boundary_session_id" -> :boundary_session_id
      "attempt_ref" -> :attempt_ref
      "route_id" -> :route_id
      "event_id" -> :event_id
      "idempotency_key" -> :idempotency_key
      "extensions" -> :extensions
      _other -> raise ArgumentError, "unknown lineage key: #{inspect(key)}"
    end
  end

  defp normalize_lineage_key!(key),
    do: raise(ArgumentError, "unknown lineage key: #{inspect(key)}")

  defp maybe_backfill_trace_id(lineage, required_keys) do
    if :trace_id in required_keys and is_nil(Map.get(lineage, :trace_id)) do
      case Map.get(lineage, :request_id) do
        request_id when is_binary(request_id) and byte_size(request_id) > 0 ->
          backfilled_lineage = Map.put(lineage, :trace_id, request_id)

          :telemetry.execute(
            [:lower_gateway, :trace_id, :backfill],
            %{count: 1},
            %{
              consumer: :execution_plane_contracts,
              source: :request_id,
              trace_id: backfilled_lineage.trace_id,
              tenant_id: Map.get(backfilled_lineage, :tenant_id),
              request_id: backfilled_lineage.request_id,
              decision_id: Map.get(backfilled_lineage, :decision_id),
              boundary_session_id: Map.get(backfilled_lineage, :boundary_session_id),
              route_id: Map.get(backfilled_lineage, :route_id)
            }
          )

          backfilled_lineage

        _other ->
          lineage
      end
    else
      lineage
    end
  end
end
