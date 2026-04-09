defmodule ExecutionPlane.Contracts.ExecutionEvent.V1 do
  @moduledoc """
  Append-only raw execution fact emitted by the Execution Plane.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:execution_event_v1)
  @required_lineage_keys [
    :tenant_id,
    :request_id,
    :decision_id,
    :boundary_session_id,
    :attempt_ref,
    :route_id,
    :event_id,
    :idempotency_key
  ]

  defstruct [
    :contract_version,
    :event_id,
    :route_id,
    :event_type,
    :timestamp,
    lineage: %{},
    payload: %{}
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          event_id: String.t(),
          route_id: String.t(),
          event_type: String.t(),
          timestamp: String.t(),
          lineage: Contracts.lineage_t(),
          payload: map()
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
  def dump(%__MODULE__{} = event) do
    %{
      "contract_version" => event.contract_version,
      "event_id" => event.event_id,
      "route_id" => event.route_id,
      "event_type" => event.event_type,
      "timestamp" => event.timestamp,
      "lineage" => Contracts.dump_lineage(event.lineage),
      "payload" => Contracts.stringify_keys(event.payload)
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)
    event_id = Contracts.fetch_required_stringish!(attrs, :event_id)
    route_id = Contracts.fetch_required_stringish!(attrs, :route_id)

    lineage =
      attrs
      |> Contracts.fetch_required_map!(:lineage)
      |> Contracts.normalize_lineage!(@required_lineage_keys)

    Contracts.maybe_match_lineage!(event_id, lineage, :event_id, "event_id")
    Contracts.maybe_match_lineage!(route_id, lineage, :route_id, "route_id")

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      event_id: event_id,
      route_id: route_id,
      event_type: Contracts.fetch_required_stringish!(attrs, :event_type),
      timestamp:
        attrs
        |> Contracts.fetch_required_stringish!(:timestamp)
        |> Contracts.validate_iso8601!("timestamp"),
      lineage: lineage,
      payload: Contracts.fetch_optional_map!(attrs, :payload, %{})
    }
  end
end
