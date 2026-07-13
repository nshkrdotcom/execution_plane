defmodule ExecutionPlane.Contracts.LowerSimulationEvidence.V1 do
  @moduledoc """
  Bounded evidence that a lower-runtime simulation scenario produced an
  `ExecutionOutcome.v1` without external side effects.

  The raw lower-family payload remains in `ExecutionOutcome.v1.raw_payload`.
  This wrapper records only hashes, shapes, and side-effect policy facts so
  evidence consumers do not need to reinterpret or narrow the v1 raw payload.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:lower_simulation_evidence_v1)
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
  @side_effect_policies ["deny_external_egress", "deny_process_spawn"]
  @side_effect_results ["not_attempted", "blocked_before_dispatch"]
  @forbidden_fingerprint_keys ~w(body raw_body payload prompt input stdin stdout stderr headers)

  defstruct [
    :contract_version,
    :scenario_ref,
    :route_id,
    :family,
    :protocol,
    :side_effect_policy,
    :side_effect_result,
    :outcome_contract_version,
    :outcome_status,
    :outcome_family,
    input_fingerprint: %{},
    output_fingerprint: %{},
    raw_payload_shape: [],
    lineage: %{}
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          scenario_ref: String.t(),
          route_id: String.t(),
          family: String.t(),
          protocol: String.t(),
          side_effect_policy: String.t(),
          side_effect_result: String.t(),
          outcome_contract_version: String.t(),
          outcome_status: String.t(),
          outcome_family: String.t(),
          input_fingerprint: map(),
          output_fingerprint: map(),
          raw_payload_shape: [String.t()],
          lineage: Contracts.lineage_t()
        }

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

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

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = evidence) do
    %{
      "contract_version" => evidence.contract_version,
      "scenario_ref" => evidence.scenario_ref,
      "route_id" => evidence.route_id,
      "family" => evidence.family,
      "protocol" => evidence.protocol,
      "side_effect_policy" => evidence.side_effect_policy,
      "side_effect_result" => evidence.side_effect_result,
      "outcome_contract_version" => evidence.outcome_contract_version,
      "outcome_status" => evidence.outcome_status,
      "outcome_family" => evidence.outcome_family,
      "input_fingerprint" => Contracts.stringify_keys(evidence.input_fingerprint),
      "output_fingerprint" => Contracts.stringify_keys(evidence.output_fingerprint),
      "raw_payload_shape" => evidence.raw_payload_shape,
      "lineage" => Contracts.dump_lineage(evidence.lineage)
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)
    route_id = Contracts.fetch_required_stringish!(attrs, :route_id)
    outcome_family = Contracts.fetch_required_stringish!(attrs, :outcome_family)
    family = Contracts.fetch_required_stringish!(attrs, :family)

    lineage =
      attrs
      |> Contracts.fetch_required_map!(:lineage)
      |> Contracts.normalize_lineage!(@required_lineage_keys)

    Contracts.maybe_match_lineage!(route_id, lineage, :route_id, "route_id")

    validate_family_match!(family, outcome_family)

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      scenario_ref: Contracts.fetch_required_stringish!(attrs, :scenario_ref),
      route_id: route_id,
      family: family,
      protocol: Contracts.fetch_required_stringish!(attrs, :protocol),
      side_effect_policy:
        attrs
        |> Contracts.fetch_required_stringish!(:side_effect_policy)
        |> validate_supported!(:side_effect_policy, @side_effect_policies),
      side_effect_result:
        attrs
        |> Contracts.fetch_required_stringish!(:side_effect_result)
        |> validate_supported!(:side_effect_result, @side_effect_results),
      outcome_contract_version:
        Contracts.fetch_required_stringish!(attrs, :outcome_contract_version),
      outcome_status: Contracts.fetch_required_stringish!(attrs, :outcome_status),
      outcome_family: outcome_family,
      input_fingerprint: validate_fingerprint!(attrs, :input_fingerprint),
      output_fingerprint: validate_fingerprint!(attrs, :output_fingerprint),
      raw_payload_shape: validate_raw_payload_shape!(attrs),
      lineage: lineage
    }
  end

  defp validate_supported!(value, field, supported) do
    if value in supported do
      value
    else
      raise ArgumentError, "#{field} is not supported: #{inspect(value)}"
    end
  end

  defp validate_family_match!(family, family), do: :ok

  defp validate_family_match!(family, outcome_family) do
    raise ArgumentError,
          "family must match outcome_family, got: #{inspect(family)} and #{inspect(outcome_family)}"
  end

  defp validate_fingerprint!(attrs, field) do
    fingerprint =
      attrs
      |> Contracts.fetch_required_map!(field)
      |> Contracts.stringify_keys()

    Enum.each(@forbidden_fingerprint_keys, fn key ->
      if Map.has_key?(fingerprint, key) do
        raise ArgumentError, "#{field} must not carry raw #{key}"
      end
    end)

    case {Map.fetch(fingerprint, "sha256"), Map.fetch(fingerprint, "byte_size")} do
      {{:ok, "sha256:" <> hash}, {:ok, byte_size}}
      when byte_size(hash) == 64 and is_integer(byte_size) and byte_size >= 0 ->
        fingerprint

      _other ->
        raise ArgumentError, "#{field} must include sha256 and non-negative byte_size"
    end
  end

  defp validate_raw_payload_shape!(attrs) do
    attrs
    |> Contracts.fetch_required_list!(:raw_payload_shape, fn value ->
      Contracts.validate_non_empty_string!(value, "raw_payload_shape")
    end)
    |> Enum.sort()
  end
end
