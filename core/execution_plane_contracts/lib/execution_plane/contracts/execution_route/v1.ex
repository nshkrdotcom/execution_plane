defmodule ExecutionPlane.Contracts.ExecutionRoute.V1 do
  @moduledoc """
  Spine-owned durable route choice carried to and from the Execution Plane.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:execution_route_v1)
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

  defstruct [
    :contract_version,
    :route_id,
    :family,
    :protocol,
    :transport_family,
    :placement_family,
    resolved_target: %{},
    resolved_budget: %{},
    lineage: %{}
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          route_id: String.t(),
          family: String.t(),
          protocol: String.t(),
          transport_family: String.t(),
          placement_family: String.t(),
          resolved_target: map(),
          resolved_budget: map(),
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
  def dump(%__MODULE__{} = route) do
    %{
      "contract_version" => route.contract_version,
      "route_id" => route.route_id,
      "family" => route.family,
      "protocol" => route.protocol,
      "transport_family" => route.transport_family,
      "placement_family" => route.placement_family,
      "resolved_target" => Contracts.stringify_keys(route.resolved_target),
      "resolved_budget" => Contracts.stringify_keys(route.resolved_budget),
      "lineage" => Contracts.dump_lineage(route.lineage)
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
      family: Contracts.fetch_required_stringish!(attrs, :family),
      protocol: Contracts.fetch_required_stringish!(attrs, :protocol),
      transport_family: Contracts.fetch_required_stringish!(attrs, :transport_family),
      placement_family: Contracts.fetch_required_stringish!(attrs, :placement_family),
      resolved_target: Contracts.fetch_optional_map!(attrs, :resolved_target, %{}),
      resolved_budget: Contracts.fetch_optional_map!(attrs, :resolved_budget, %{}),
      lineage: lineage
    }
  end
end
