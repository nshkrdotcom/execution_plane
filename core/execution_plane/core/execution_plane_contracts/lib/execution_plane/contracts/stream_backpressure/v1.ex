defmodule ExecutionPlane.Contracts.StreamBackpressure.V1 do
  @moduledoc """
  Deterministic stream pressure and termination evidence.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:stream_backpressure_v1)
  @pressure_classes ["soft_pressure", "hard_pressure", "budget_exhausted"]

  defstruct [
    :contract_version,
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :principal_ref,
    :system_actor_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref,
    :stream_ref,
    :budget_ref,
    :pressure_class,
    :termination_reason,
    :last_heartbeat_at,
    :diagnostics_ref
  ]

  @type t :: %__MODULE__{}

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
  def dump(%__MODULE__{} = event), do: event |> Map.from_struct() |> stringify_contract()

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)
    {principal_ref, system_actor_ref} = Contracts.fetch_required_actor_refs!(attrs)
    pressure_class = Contracts.fetch_required_stringish!(attrs, :pressure_class)

    unless pressure_class in @pressure_classes do
      raise ArgumentError, "pressure_class is not supported: #{inspect(pressure_class)}"
    end

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      tenant_ref: Contracts.fetch_required_stringish!(attrs, :tenant_ref),
      installation_ref: Contracts.fetch_required_stringish!(attrs, :installation_ref),
      workspace_ref: Contracts.fetch_required_stringish!(attrs, :workspace_ref),
      project_ref: Contracts.fetch_required_stringish!(attrs, :project_ref),
      environment_ref: Contracts.fetch_required_stringish!(attrs, :environment_ref),
      principal_ref: principal_ref,
      system_actor_ref: system_actor_ref,
      resource_ref: Contracts.fetch_required_stringish!(attrs, :resource_ref),
      authority_packet_ref: Contracts.fetch_required_stringish!(attrs, :authority_packet_ref),
      permission_decision_ref:
        Contracts.fetch_required_stringish!(attrs, :permission_decision_ref),
      idempotency_key: Contracts.fetch_required_stringish!(attrs, :idempotency_key),
      trace_id: Contracts.fetch_required_stringish!(attrs, :trace_id),
      correlation_id: Contracts.fetch_required_stringish!(attrs, :correlation_id),
      release_manifest_ref: Contracts.fetch_required_stringish!(attrs, :release_manifest_ref),
      stream_ref: Contracts.fetch_required_stringish!(attrs, :stream_ref),
      budget_ref: Contracts.fetch_required_stringish!(attrs, :budget_ref),
      pressure_class: pressure_class,
      termination_reason: Contracts.fetch_required_stringish!(attrs, :termination_reason),
      last_heartbeat_at:
        attrs
        |> Contracts.fetch_required_stringish!(:last_heartbeat_at)
        |> Contracts.validate_iso8601!("last_heartbeat_at"),
      diagnostics_ref: Contracts.fetch_required_stringish!(attrs, :diagnostics_ref)
    }
  end

  defp stringify_contract(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), value} end)
  end
end
