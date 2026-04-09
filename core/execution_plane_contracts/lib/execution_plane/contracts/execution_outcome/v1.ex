defmodule ExecutionPlane.Contracts.ExecutionOutcome.V1 do
  @moduledoc """
  Terminal or checkpointed raw execution outcome emitted by the Execution Plane.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.Failure

  @contract_version Contracts.contract_version!(:execution_outcome_v1)
  @required_lineage_keys [
    :tenant_id,
    :request_id,
    :decision_id,
    :boundary_session_id,
    :attempt_ref,
    :route_id,
    :idempotency_key
  ]

  defstruct [
    :contract_version,
    :route_id,
    :status,
    :family,
    :failure,
    raw_payload: %{},
    artifacts: [],
    metrics: %{},
    lineage: %{}
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          route_id: String.t(),
          status: String.t(),
          family: String.t(),
          raw_payload: map(),
          artifacts: [term()],
          metrics: map(),
          failure: Failure.t() | nil,
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
  def dump(%__MODULE__{} = outcome) do
    %{
      "contract_version" => outcome.contract_version,
      "route_id" => outcome.route_id,
      "status" => outcome.status,
      "family" => outcome.family,
      "raw_payload" => Contracts.stringify_keys(outcome.raw_payload),
      "artifacts" => Contracts.stringify_keys(outcome.artifacts),
      "metrics" => Contracts.stringify_keys(outcome.metrics),
      "failure" => maybe_dump_failure(outcome.failure),
      "lineage" => Contracts.dump_lineage(outcome.lineage)
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)
    route_id = Contracts.fetch_required_stringish!(attrs, :route_id)

    lineage =
      attrs
      |> Contracts.fetch_required_map!(:lineage)
      |> Contracts.normalize_lineage!(@required_lineage_keys)

    Contracts.maybe_match_lineage!(route_id, lineage, :route_id, "route_id")

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      route_id: route_id,
      status: Contracts.fetch_required_stringish!(attrs, :status),
      family: Contracts.fetch_required_stringish!(attrs, :family),
      raw_payload: Contracts.fetch_optional_map!(attrs, :raw_payload, %{}),
      artifacts: normalize_artifacts(Contracts.fetch_value(attrs, :artifacts)),
      metrics: Contracts.fetch_optional_map!(attrs, :metrics, %{}),
      failure: normalize_failure(Contracts.fetch_value(attrs, :failure)),
      lineage: lineage
    }
  end

  defp normalize_artifacts(nil), do: []
  defp normalize_artifacts(values) when is_list(values), do: values

  defp normalize_artifacts(values) do
    raise ArgumentError, "artifacts must be a list, got: #{inspect(values)}"
  end

  defp normalize_failure(nil), do: nil
  defp normalize_failure(%Failure{} = failure), do: failure
  defp normalize_failure(attrs), do: Failure.new!(attrs)

  defp maybe_dump_failure(nil), do: nil
  defp maybe_dump_failure(%Failure{} = failure), do: Failure.dump(failure)
end
