defmodule ExecutionPlane.Contracts.StreamAttachRevocation.V1 do
  @moduledoc """
  Revocation evidence proving an attached stream stopped after grant or lease revocation.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:stream_attach_revocation_v1)

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
    :attach_grant_ref,
    :lease_ref,
    :revocation_ref,
    :termination_ref,
    :last_event_position
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
      attach_grant_ref: Contracts.fetch_required_stringish!(attrs, :attach_grant_ref),
      lease_ref: Contracts.fetch_required_stringish!(attrs, :lease_ref),
      revocation_ref: Contracts.fetch_required_stringish!(attrs, :revocation_ref),
      termination_ref: Contracts.fetch_required_stringish!(attrs, :termination_ref),
      last_event_position: Contracts.fetch_required_non_neg_integer!(attrs, :last_event_position)
    }
  end

  defp stringify_contract(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), value} end)
  end
end
