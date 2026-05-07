defmodule ExecutionPlane.Contracts.AttachGrant.V1 do
  @moduledoc """
  Phase 4 lease-bound attach grant for hazmat stream/session access.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:attach_grant_v1)

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
    :attach_grant_ref,
    :lease_ref,
    :target_ref,
    :target_auth_posture,
    :target_auth_posture_ref,
    :boundary_session_id,
    :no_egress_posture_ref,
    :process_target_identity_ref,
    :stream_target_identity_ref,
    :hazmat_resource_ref,
    :grant_scope,
    :expires_at,
    :revocation_ref,
    :persistence_posture,
    credential_handle_refs: [],
    provider_account_refs: [],
    connector_instance_refs: [],
    cleanup_refs: []
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          tenant_ref: String.t(),
          installation_ref: String.t(),
          workspace_ref: String.t(),
          project_ref: String.t(),
          environment_ref: String.t(),
          principal_ref: String.t() | nil,
          system_actor_ref: String.t() | nil,
          resource_ref: String.t(),
          authority_packet_ref: String.t(),
          permission_decision_ref: String.t(),
          idempotency_key: String.t(),
          trace_id: String.t(),
          correlation_id: String.t(),
          release_manifest_ref: String.t(),
          attach_grant_ref: String.t(),
          lease_ref: String.t(),
          target_ref: String.t() | nil,
          target_auth_posture: String.t() | nil,
          target_auth_posture_ref: String.t() | nil,
          boundary_session_id: String.t() | nil,
          no_egress_posture_ref: String.t() | nil,
          process_target_identity_ref: String.t() | nil,
          stream_target_identity_ref: String.t() | nil,
          hazmat_resource_ref: String.t(),
          grant_scope: map(),
          expires_at: String.t(),
          revocation_ref: String.t(),
          persistence_posture: map() | nil,
          credential_handle_refs: [String.t()],
          provider_account_refs: [String.t()],
          connector_instance_refs: [String.t()],
          cleanup_refs: [String.t()]
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
  def dump(%__MODULE__{} = grant) do
    grant
    |> Map.from_struct()
    |> Map.update!(:grant_scope, &Contracts.stringify_keys/1)
    |> stringify_contract()
  end

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
      attach_grant_ref: Contracts.fetch_required_stringish!(attrs, :attach_grant_ref),
      lease_ref: Contracts.fetch_required_stringish!(attrs, :lease_ref),
      target_ref: fetch_optional_ref!(attrs, :target_ref, "target://"),
      target_auth_posture: Contracts.fetch_optional_stringish!(attrs, :target_auth_posture),
      target_auth_posture_ref:
        fetch_optional_ref!(attrs, :target_auth_posture_ref, "target-posture://"),
      boundary_session_id: Contracts.fetch_optional_stringish!(attrs, :boundary_session_id),
      no_egress_posture_ref:
        fetch_optional_ref!(attrs, :no_egress_posture_ref, "no-egress-posture://"),
      process_target_identity_ref:
        fetch_optional_ref!(attrs, :process_target_identity_ref, "process-target-identity://"),
      stream_target_identity_ref:
        fetch_optional_ref!(attrs, :stream_target_identity_ref, "stream-target-identity://"),
      hazmat_resource_ref: Contracts.fetch_required_stringish!(attrs, :hazmat_resource_ref),
      grant_scope: Contracts.fetch_required_map!(attrs, :grant_scope),
      expires_at:
        attrs
        |> Contracts.fetch_required_stringish!(:expires_at)
        |> Contracts.validate_iso8601!("expires_at"),
      revocation_ref: Contracts.fetch_required_stringish!(attrs, :revocation_ref),
      persistence_posture:
        ExecutionPlane.Contracts.PersistencePosture.resolve(:attach_grant, attrs),
      credential_handle_refs:
        Contracts.fetch_optional_list!(
          attrs,
          :credential_handle_refs,
          [],
          &validate_credential_handle_ref!/1
        ),
      provider_account_refs:
        fetch_optional_ref_list!(attrs, :provider_account_refs, "provider-account://"),
      connector_instance_refs:
        fetch_optional_ref_list!(attrs, :connector_instance_refs, "connector-instance://"),
      cleanup_refs: fetch_optional_ref_list!(attrs, :cleanup_refs, "cleanup://")
    }
  end

  defp fetch_optional_ref!(attrs, key, prefix) do
    case Contracts.fetch_optional_stringish!(attrs, key) do
      nil -> nil
      value -> validate_ref_prefix!(value, to_string(key), prefix)
    end
  end

  defp fetch_optional_ref_list!(attrs, key, prefix) do
    Contracts.fetch_optional_list!(
      attrs,
      key,
      [],
      &validate_ref_prefix!(&1, to_string(key), prefix)
    )
  end

  defp validate_credential_handle_ref!(value) do
    value = Contracts.validate_opaque_handle_ref!(value, "credential_handle_ref")

    if String.starts_with?(value, "credential-handle://") or
         String.starts_with?(value, "urn:credential-handle:") do
      value
    else
      raise ArgumentError,
            "credential_handle_ref must start with credential-handle:// or urn:credential-handle:, got: #{inspect(value)}"
    end
  end

  defp validate_ref_prefix!(value, field_name, prefix) do
    value = Contracts.validate_non_empty_string!(value, field_name)

    if String.starts_with?(value, prefix) do
      value
    else
      raise ArgumentError, "#{field_name} must start with #{prefix}, got: #{inspect(value)}"
    end
  end

  defp stringify_contract(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), value} end)
  end
end
