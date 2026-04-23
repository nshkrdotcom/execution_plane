defmodule ExecutionPlane.Contracts.ExecutionEvidenceBoundary.V1 do
  @moduledoc """
  Bounded report boundary for `ExecutionOutcome.v1`.

  The raw payload remains owned by `ExecutionOutcome.v1`. This contract only
  carries shapes, refs, and scan results that are safe to persist in evidence
  reports.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.ExecutionOutcome.V1, as: ExecutionOutcome
  alias ExecutionPlane.Contracts.LowerSimulationEvidence.V1, as: LowerSimulationEvidence

  @contract_version Contracts.contract_version!(:execution_evidence_boundary_v1)
  @owner_repo "execution_plane"
  @schema_ref "schema://execution-plane/execution-evidence-boundary/v1"
  @raw_scan_ref "ExecutionPlane.ExecutionEvidenceBoundary.v1.raw_payload_scan"
  @forbidden_semantic_keys [
    :provider_refs,
    :model_refs,
    :budget_profile_ref,
    :meter_profile_ref,
    :semantic_policy,
    :cost_policy
  ]
  @forbidden_raw_keys ~w(
    api_key
    authorization
    body
    payload
    prompt
    provider_body
    raw_body
    raw_payload
    secret
    semantic_body
    workflow_history
  )
  @shape_only_keys ~w(
    checked_for
    header_keys
    raw_payload_included
    raw_payload_shape
    rejected_findings
    scan_scope
    scanner_ref
  )

  defstruct [
    :contract_version,
    :owner_repo,
    :outcome_ref,
    :bounded_status,
    :bounded_exit_code_or_response_shape,
    :input_fingerprint_ref,
    :claim_check_ref_or_null,
    :redacted_preview_ref_or_null,
    :schema_ref,
    :scan_result
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          owner_repo: String.t(),
          outcome_ref: String.t(),
          bounded_status: String.t(),
          bounded_exit_code_or_response_shape: map(),
          input_fingerprint_ref: String.t(),
          claim_check_ref_or_null: String.t() | nil,
          redacted_preview_ref_or_null: String.t() | nil,
          schema_ref: String.t(),
          scan_result: map()
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

  @spec from_outcome!(ExecutionOutcome.t(), keyword()) :: t()
  def from_outcome!(%ExecutionOutcome{} = outcome, opts \\ []) do
    lower_evidence =
      opts
      |> Keyword.fetch!(:lower_simulation_evidence)
      |> LowerSimulationEvidence.new!()

    new!(%{
      owner_repo: @owner_repo,
      outcome_ref: Keyword.get(opts, :outcome_ref, "execution-outcome://#{outcome.route_id}"),
      bounded_status: outcome.status,
      bounded_exit_code_or_response_shape: bounded_shape(outcome),
      input_fingerprint_ref: fingerprint_ref(lower_evidence.input_fingerprint),
      claim_check_ref_or_null: Keyword.get(opts, :claim_check_ref_or_null),
      redacted_preview_ref_or_null: Keyword.get(opts, :redacted_preview_ref_or_null),
      schema_ref: Keyword.get(opts, :schema_ref, @schema_ref),
      scan_result: scan_result("passed")
    })
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = boundary) do
    %{
      "contract_version" => boundary.contract_version,
      "owner_repo" => boundary.owner_repo,
      "outcome_ref" => boundary.outcome_ref,
      "bounded_status" => boundary.bounded_status,
      "bounded_exit_code_or_response_shape" =>
        Contracts.stringify_keys(boundary.bounded_exit_code_or_response_shape),
      "input_fingerprint_ref" => boundary.input_fingerprint_ref,
      "claim_check_ref_or_null" => boundary.claim_check_ref_or_null,
      "redacted_preview_ref_or_null" => boundary.redacted_preview_ref_or_null,
      "schema_ref" => boundary.schema_ref,
      "scan_result" => Contracts.stringify_keys(boundary.scan_result)
    }
  end

  @spec scan_result(String.t()) :: map()
  def scan_result(status) do
    %{
      "status" => status,
      "raw_payload_included" => false,
      "scanner_ref" => @raw_scan_ref,
      "scan_scope" => "bounded_evidence_fields",
      "checked_for" => [
        "raw_prompt",
        "provider_body",
        "secret",
        "workflow_history",
        "unbounded_semantic_body"
      ],
      "rejected_findings" => []
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)
    reject_semantic_provider_policy!(attrs)

    bounded_shape =
      attrs
      |> Contracts.fetch_required_map!(:bounded_exit_code_or_response_shape)
      |> Contracts.stringify_keys()
      |> reject_raw_durable_evidence!()

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      owner_repo: validate_owner_repo!(Contracts.fetch_required_stringish!(attrs, :owner_repo)),
      outcome_ref:
        Contracts.validate_opaque_handle_ref!(
          Contracts.fetch_required_stringish!(attrs, :outcome_ref),
          "outcome_ref"
        ),
      bounded_status: Contracts.fetch_required_stringish!(attrs, :bounded_status),
      bounded_exit_code_or_response_shape: bounded_shape,
      input_fingerprint_ref:
        Contracts.validate_opaque_handle_ref!(
          Contracts.fetch_required_stringish!(attrs, :input_fingerprint_ref),
          "input_fingerprint_ref"
        ),
      claim_check_ref_or_null: optional_ref(attrs, :claim_check_ref_or_null),
      redacted_preview_ref_or_null: optional_ref(attrs, :redacted_preview_ref_or_null),
      schema_ref:
        Contracts.validate_opaque_handle_ref!(
          Contracts.fetch_required_stringish!(attrs, :schema_ref),
          "schema_ref"
        ),
      scan_result: validate_scan_result!(attrs)
    }
  end

  defp validate_owner_repo!(@owner_repo), do: @owner_repo

  defp validate_owner_repo!(owner_repo) do
    raise ArgumentError, "owner_repo must be #{@owner_repo}, got: #{inspect(owner_repo)}"
  end

  defp optional_ref(attrs, key) do
    case Contracts.fetch_value(attrs, key) do
      nil -> nil
      value -> Contracts.validate_opaque_handle_ref!(value, to_string(key))
    end
  end

  defp validate_scan_result!(attrs) do
    scan =
      attrs
      |> Contracts.fetch_required_map!(:scan_result)
      |> Contracts.stringify_keys()

    unless Map.get(scan, "status") == "passed" do
      raise ArgumentError, "scan_result.status must be passed"
    end

    unless Map.get(scan, "raw_payload_included") == false do
      raise ArgumentError, "scan_result.raw_payload_included must be false"
    end

    reject_raw_durable_evidence!(scan)
  end

  defp reject_semantic_provider_policy!(attrs) do
    if Enum.any?(@forbidden_semantic_keys, &has_key?(attrs, &1)) do
      raise ArgumentError,
            "ExecutionEvidenceBoundary must not carry provider or model or budget semantics"
    end
  end

  defp has_key?(attrs, key),
    do: Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key))

  defp reject_raw_durable_evidence!(value), do: reject_raw_durable_evidence!(value, [])

  defp reject_raw_durable_evidence!(value, path) when is_map(value) do
    Enum.each(value, fn {key, nested} ->
      key = to_string(key)

      cond do
        key in @shape_only_keys ->
          :ok

        forbidden_raw_key?(key) ->
          raise_raw_durable_evidence!(Enum.reverse([key | path]))

        true ->
          reject_raw_durable_evidence!(nested, [key | path])
      end
    end)

    value
  end

  defp reject_raw_durable_evidence!(values, path) when is_list(values) do
    Enum.each(values, &reject_raw_durable_evidence!(&1, path))
    values
  end

  defp reject_raw_durable_evidence!(value, path) when is_binary(value) do
    if raw_string?(value), do: raise_raw_durable_evidence!(Enum.reverse(path))
    value
  end

  defp reject_raw_durable_evidence!(value, _path), do: value

  defp forbidden_raw_key?(key) do
    normalized = String.downcase(key)
    normalized in @forbidden_raw_keys
  end

  defp raw_string?(value) do
    normalized = String.downcase(value)

    String.contains?(normalized, [
      "raw prompt",
      "raw provider body",
      "sk-live",
      "workflow history",
      "unbounded semantic"
    ])
  end

  defp raise_raw_durable_evidence!(path) do
    raise ArgumentError,
          "raw durable evidence is forbidden at #{Enum.join(path, ".")}"
  end

  defp bounded_shape(%ExecutionOutcome{} = outcome) do
    raw_payload = Contracts.stringify_keys(outcome.raw_payload)

    %{
      "family" => outcome.family,
      "raw_payload_shape" => raw_payload |> Map.keys() |> Enum.sort()
    }
    |> maybe_put("status_code", Map.get(raw_payload, "status_code"))
    |> maybe_put("exit_code", exit_code(raw_payload))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp exit_code(%{"exit" => %{"code" => code}}) when is_integer(code), do: code
  defp exit_code(%{"exit_status" => code}) when is_integer(code), do: code
  defp exit_code(_raw_payload), do: nil

  defp fingerprint_ref(%{"sha256" => "sha256:" <> hash}) do
    "fingerprint://execution-plane/input/#{hash}"
  end

  defp fingerprint_ref(%{sha256: "sha256:" <> hash}) do
    "fingerprint://execution-plane/input/#{hash}"
  end
end
