defmodule ExecutionPlane.Contracts.LaneFact.V1 do
  @moduledoc """
  Neutral bounded lower-lane fact.

  `LaneFact.v1` is the safe shape handed upward from Execution Plane lanes. Raw
  stdout, stderr, HTTP bodies, workflow histories, credentials, and product
  workflow decisions remain outside this contract.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.ExecutionEvent.V1, as: ExecutionEvent
  alias ExecutionPlane.Contracts.ExecutionOutcome.V1, as: ExecutionOutcome

  @contract_version Contracts.contract_version!(:lane_fact_v1)
  @required_lineage_keys [
    :tenant_id,
    :trace_id,
    :request_id,
    :decision_id,
    :boundary_session_id,
    :attempt_ref,
    :route_id,
    :idempotency_key
  ]
  @phases ~w(started chunk frame completed failed timeout cancelled)
  @forbidden_payload_keys ~w(
    access_token
    api_key
    authorization
    body
    bypass_citadel
    citadel_bypass
    credential
    credentials
    private_key
    product_state
    prompt
    raw_credential
    raw_payload
    refresh_token
    secret
    stderr
    stdout
    workflow_decision
    workflow_history
    workflow_state
  )
  @forbidden_string_fragments [
    "authorization:",
    "citadel bypass",
    "product workflow",
    "raw credential",
    "raw provider body",
    "sk-live",
    "workflow decision",
    "workflow history"
  ]

  defstruct [
    :contract_version,
    :fact_ref,
    :route_id,
    :lane_id,
    :family,
    :protocol,
    :phase,
    :transport_ref,
    :timestamp,
    :sequence,
    :output_byte_size,
    :max_output_bytes,
    :output_hash_ref,
    :output_ref,
    :redacted_preview_ref,
    lineage: %{},
    payload_shape: %{},
    evidence_refs: []
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          fact_ref: String.t(),
          route_id: String.t(),
          lane_id: String.t(),
          family: String.t(),
          protocol: String.t(),
          phase: String.t(),
          transport_ref: String.t(),
          timestamp: String.t(),
          sequence: non_neg_integer(),
          output_byte_size: non_neg_integer(),
          max_output_bytes: pos_integer(),
          output_hash_ref: String.t(),
          output_ref: String.t() | nil,
          redacted_preview_ref: String.t() | nil,
          lineage: Contracts.lineage_t(),
          payload_shape: map(),
          evidence_refs: [String.t()]
        }

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec phases() :: [String.t(), ...]
  def phases, do: @phases

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    {:ok, build(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(map() | keyword() | t()) :: t()
  def new!(%__MODULE__{} = value), do: value

  def new!(attrs) do
    case new(attrs) do
      {:ok, value} -> value
      {:error, error} -> raise error
    end
  end

  @spec from_event!(ExecutionEvent.t(), keyword()) :: t()
  def from_event!(%ExecutionEvent{} = event, opts \\ []) do
    payload_shape =
      event.payload
      |> Contracts.stringify_keys()
      |> shape_from_map()

    phase = Keyword.get(opts, :phase, phase_from_event_type(event.event_type))

    new!(%{
      fact_ref:
        Keyword.get(opts, :fact_ref) ||
          fact_ref(event.route_id, phase, Keyword.get(opts, :sequence, 0)),
      route_id: event.route_id,
      lane_id: Keyword.fetch!(opts, :lane_id),
      family:
        Keyword.get(opts, :family) || Map.get(event.payload, "family") ||
          Map.get(event.payload, :family),
      protocol:
        Keyword.get(opts, :protocol) || Map.get(event.payload, "protocol") ||
          Map.get(event.payload, :protocol),
      phase: phase,
      transport_ref: Keyword.fetch!(opts, :transport_ref),
      timestamp: event.timestamp,
      sequence: Keyword.get(opts, :sequence, 0),
      output_byte_size: Keyword.get(opts, :output_byte_size, 0),
      max_output_bytes: Keyword.fetch!(opts, :max_output_bytes),
      output_hash_ref: Keyword.get(opts, :output_hash_ref) || safe_hash_ref(payload_shape),
      output_ref: Keyword.get(opts, :output_ref),
      redacted_preview_ref: Keyword.get(opts, :redacted_preview_ref),
      lineage: event.lineage,
      payload_shape: payload_shape,
      evidence_refs: Keyword.get(opts, :evidence_refs, [])
    })
  end

  @spec from_outcome!(ExecutionOutcome.t(), keyword()) :: t()
  def from_outcome!(%ExecutionOutcome{} = outcome, opts \\ []) do
    payload_shape = %{
      "family" => outcome.family,
      "raw_payload_shape" =>
        outcome.raw_payload
        |> Contracts.stringify_keys()
        |> Map.keys()
        |> Enum.sort()
    }

    phase = Keyword.get(opts, :phase, phase_from_outcome(outcome))

    new!(%{
      fact_ref:
        Keyword.get(opts, :fact_ref) ||
          fact_ref(outcome.route_id, phase, Keyword.get(opts, :sequence, 0)),
      route_id: outcome.route_id,
      lane_id: Keyword.fetch!(opts, :lane_id),
      family: Keyword.get(opts, :family) || outcome.family,
      protocol: Keyword.fetch!(opts, :protocol),
      phase: phase,
      transport_ref: Keyword.fetch!(opts, :transport_ref),
      timestamp:
        Keyword.get_lazy(opts, :timestamp, fn -> DateTime.utc_now() |> DateTime.to_iso8601() end),
      sequence: Keyword.get(opts, :sequence, 0),
      output_byte_size: Keyword.get(opts, :output_byte_size, 0),
      max_output_bytes: Keyword.fetch!(opts, :max_output_bytes),
      output_hash_ref: Keyword.get(opts, :output_hash_ref) || safe_hash_ref(payload_shape),
      output_ref: Keyword.get(opts, :output_ref),
      redacted_preview_ref: Keyword.get(opts, :redacted_preview_ref),
      lineage: outcome.lineage,
      payload_shape: payload_shape,
      evidence_refs: Keyword.get(opts, :evidence_refs, [])
    })
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = fact) do
    %{
      "contract_version" => fact.contract_version,
      "fact_ref" => fact.fact_ref,
      "route_id" => fact.route_id,
      "lane_id" => fact.lane_id,
      "family" => fact.family,
      "protocol" => fact.protocol,
      "phase" => fact.phase,
      "transport_ref" => fact.transport_ref,
      "timestamp" => fact.timestamp,
      "sequence" => fact.sequence,
      "output_byte_size" => fact.output_byte_size,
      "max_output_bytes" => fact.max_output_bytes,
      "output_hash_ref" => fact.output_hash_ref,
      "output_ref" => fact.output_ref,
      "redacted_preview_ref" => fact.redacted_preview_ref,
      "lineage" => Contracts.dump_lineage(fact.lineage),
      "payload_shape" => Contracts.stringify_keys(fact.payload_shape),
      "evidence_refs" => fact.evidence_refs
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)
    route_id = Contracts.fetch_required_stringish!(attrs, :route_id)
    fact_ref = Contracts.fetch_required_stringish!(attrs, :fact_ref)

    output_byte_size =
      non_negative_integer!(Contracts.fetch_value(attrs, :output_byte_size), :output_byte_size)

    max_output_bytes =
      positive_integer!(Contracts.fetch_value(attrs, :max_output_bytes), :max_output_bytes)

    payload_shape =
      attrs |> Contracts.fetch_optional_map!(:payload_shape, %{}) |> Contracts.stringify_keys()

    Contracts.maybe_match_lineage!(route_id, normalize_lineage!(attrs), :route_id, "route_id")

    if output_byte_size > max_output_bytes do
      raise ArgumentError, "output_byte_size exceeds max_output_bytes"
    end

    reject_forbidden_payload!(payload_shape)

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      fact_ref: Contracts.validate_opaque_handle_ref!(fact_ref, "fact_ref"),
      route_id: route_id,
      lane_id: Contracts.fetch_required_stringish!(attrs, :lane_id),
      family: Contracts.fetch_required_stringish!(attrs, :family),
      protocol: Contracts.fetch_required_stringish!(attrs, :protocol),
      phase: validate_phase!(Contracts.fetch_required_stringish!(attrs, :phase)),
      transport_ref:
        attrs
        |> Contracts.fetch_required_stringish!(:transport_ref)
        |> Contracts.validate_opaque_handle_ref!("transport_ref"),
      timestamp:
        attrs
        |> Contracts.fetch_required_stringish!(:timestamp)
        |> Contracts.validate_iso8601!("timestamp"),
      sequence: non_negative_integer!(Contracts.fetch_value(attrs, :sequence), :sequence),
      output_byte_size: output_byte_size,
      max_output_bytes: max_output_bytes,
      output_hash_ref:
        validate_output_hash_ref!(Contracts.fetch_required_stringish!(attrs, :output_hash_ref)),
      output_ref: optional_ref(attrs, :output_ref),
      redacted_preview_ref: optional_ref(attrs, :redacted_preview_ref),
      lineage: normalize_lineage!(attrs),
      payload_shape: payload_shape,
      evidence_refs: optional_ref_list(attrs, :evidence_refs)
    }
  end

  defp normalize_lineage!(attrs) do
    attrs
    |> Contracts.fetch_required_map!(:lineage)
    |> Contracts.normalize_lineage!(@required_lineage_keys)
  end

  defp validate_phase!(phase) do
    if phase in @phases do
      phase
    else
      raise ArgumentError, "unknown lane fact phase #{inspect(phase)}"
    end
  end

  defp validate_output_hash_ref!("sha256:" <> _hash = value), do: value

  defp validate_output_hash_ref!(value),
    do: Contracts.validate_opaque_handle_ref!(value, "output_hash_ref")

  defp optional_ref(attrs, key) do
    case Contracts.fetch_value(attrs, key) do
      nil -> nil
      value -> Contracts.validate_opaque_handle_ref!(value, to_string(key))
    end
  end

  defp optional_ref_list(attrs, key) do
    Contracts.fetch_optional_list!(attrs, key, [], fn value ->
      Contracts.validate_opaque_handle_ref!(value, to_string(key))
    end)
  end

  defp non_negative_integer!(value, _key) when is_integer(value) and value >= 0, do: value

  defp non_negative_integer!(value, key) do
    raise ArgumentError, "#{key} must be a non-negative integer, got: #{inspect(value)}"
  end

  defp positive_integer!(value, _key) when is_integer(value) and value > 0, do: value

  defp positive_integer!(value, key) do
    raise ArgumentError, "#{key} must be a positive integer, got: #{inspect(value)}"
  end

  defp phase_from_event_type("dispatch.started"), do: "started"
  defp phase_from_event_type("dispatch.completed"), do: "completed"
  defp phase_from_event_type("dispatch.failed"), do: "failed"
  defp phase_from_event_type("dispatch.timeout"), do: "timeout"
  defp phase_from_event_type("dispatch.cancelled"), do: "cancelled"

  defp phase_from_event_type(event_type) when is_binary(event_type) do
    cond do
      String.contains?(event_type, "chunk") -> "chunk"
      String.contains?(event_type, "frame") -> "frame"
      true -> "started"
    end
  end

  defp phase_from_event_type(_event_type), do: "started"

  defp phase_from_outcome(%ExecutionOutcome{status: "succeeded"}), do: "completed"
  defp phase_from_outcome(%ExecutionOutcome{status: "cancelled"}), do: "cancelled"
  defp phase_from_outcome(%ExecutionOutcome{failure: %{failure_class: :timeout}}), do: "timeout"
  defp phase_from_outcome(_outcome), do: "failed"

  defp shape_from_map(map) when is_map(map), do: %{"keys" => map |> Map.keys() |> Enum.sort()}

  defp fact_ref(route_id, phase, sequence) do
    "lane-fact://#{URI.encode_www_form(route_id)}/#{phase}/#{sequence}"
  end

  defp safe_hash_ref(value) do
    material =
      value
      |> Contracts.stringify_keys()
      |> inspect(limit: :infinity, printable_limit: :infinity)

    "sha256:" <> Base.encode16(:crypto.hash(:sha256, material), case: :lower)
  end

  defp reject_forbidden_payload!(value), do: reject_forbidden_payload!(value, [])

  defp reject_forbidden_payload!(%{} = map, path) do
    Enum.each(map, fn {key, nested} ->
      key = to_string(key)

      if forbidden_key?(key) do
        raise_forbidden_payload!(Enum.reverse([key | path]))
      end

      reject_forbidden_payload!(nested, [key | path])
    end)

    map
  end

  defp reject_forbidden_payload!(values, path) when is_list(values) do
    Enum.each(values, &reject_forbidden_payload!(&1, path))
    values
  end

  defp reject_forbidden_payload!(value, path) when is_binary(value) do
    normalized = String.downcase(value)

    if Enum.any?(@forbidden_string_fragments, &String.contains?(normalized, &1)) do
      raise_forbidden_payload!(Enum.reverse(path))
    end

    value
  end

  defp reject_forbidden_payload!(value, _path), do: value

  defp forbidden_key?(key) do
    key
    |> String.downcase()
    |> then(&(&1 in @forbidden_payload_keys))
  end

  defp raise_forbidden_payload!(path) do
    raise ArgumentError, "forbidden lane fact payload at #{Enum.join(path, ".")}"
  end
end
