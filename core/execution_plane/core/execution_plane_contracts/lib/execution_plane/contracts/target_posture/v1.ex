defmodule ExecutionPlane.Contracts.TargetPosture.V1 do
  @moduledoc """
  Phase 5 target posture and attach authorization contract.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.AttachGrant.V1, as: AttachGrant
  alias ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1, as: ExecutionIntentEnvelope

  @contract_version Contracts.contract_version!(:target_posture_v1)

  @posture_aliases %{
    "no_auth" => "no_auth",
    "no-auth" => "no_auth",
    "inherit_standalone" => "inherit_standalone",
    "inherit-standalone" => "inherit_standalone",
    "assert_only" => "assert_only",
    "assert-only" => "assert_only",
    "materialize_on_attach" => "materialize_on_attach",
    "materialize-on-attach" => "materialize_on_attach",
    "mount_token_file" => "mount_token_file",
    "mount-token-file" => "mount_token_file",
    "inject_env" => "inject_env",
    "inject-env" => "inject_env",
    "native_profile" => "native_profile",
    "native-profile" => "native_profile",
    "remote_broker" => "remote_broker",
    "remote-broker" => "remote_broker",
    "multi_handle" => "multi_handle",
    "multi-handle" => "multi_handle",
    "service_identity" => "service_identity",
    "service-identity" => "service_identity",
    "forbidden" => "forbidden",
    "preinstalled" => "preinstalled",
    "proxy_only" => "proxy_only",
    "proxy-only" => "proxy_only",
    "no_credential" => "no_credential",
    "no-credential" => "no_credential"
  }

  @credential_forbidden_postures [
    "assert_only",
    "forbidden",
    "no_auth",
    "no_credential",
    "proxy_only"
  ]

  defstruct [
    :contract_version,
    :tenant_ref,
    :target_ref,
    :target_kind,
    :target_auth_posture,
    :target_auth_posture_ref,
    :boundary_session_id,
    :workspace_ref,
    :no_egress_posture_ref,
    :process_target_identity_ref,
    :stream_target_identity_ref,
    :service_identity_ref,
    allowed_provider_families: [],
    allowed_provider_account_refs: [],
    allowed_connector_instance_refs: [],
    allowed_credential_handle_refs: [],
    allowed_attach_grant_refs: [],
    cleanup_refs: [],
    materialized_state_refs: [],
    multi_handle?: false
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          tenant_ref: String.t(),
          target_ref: String.t(),
          target_kind: String.t(),
          target_auth_posture: String.t(),
          target_auth_posture_ref: String.t(),
          boundary_session_id: String.t(),
          workspace_ref: String.t(),
          no_egress_posture_ref: String.t(),
          process_target_identity_ref: String.t() | nil,
          stream_target_identity_ref: String.t() | nil,
          service_identity_ref: String.t() | nil,
          allowed_provider_families: [String.t()],
          allowed_provider_account_refs: [String.t()],
          allowed_connector_instance_refs: [String.t()],
          allowed_credential_handle_refs: [String.t()],
          allowed_attach_grant_refs: [String.t()],
          cleanup_refs: [String.t()],
          materialized_state_refs: [String.t()],
          multi_handle?: boolean()
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
  def dump(%__MODULE__{} = posture) do
    posture
    |> Map.from_struct()
    |> stringify_contract()
  end

  @spec authorize_attach(
          t() | map() | keyword(),
          AttachGrant.t() | map(),
          ExecutionIntentEnvelope.t() | map()
        ) ::
          {:ok, map()} | {:error, term()}
  def authorize_attach(posture, grant, envelope) do
    with {:ok, %__MODULE__{} = posture} <- new(posture),
         {:ok, %AttachGrant{} = grant} <- AttachGrant.new(grant),
         {:ok, %ExecutionIntentEnvelope{} = envelope} <- ExecutionIntentEnvelope.new(envelope),
         :ok <- ensure_posture_allows_credentials(posture, envelope.credential_handle_refs),
         :ok <- ensure_multi_handle(posture, envelope.credential_handle_refs),
         :ok <- ensure_equal(:target_ref, posture.target_ref, envelope.target_ref),
         :ok <- ensure_equal(:target_ref, posture.target_ref, grant.target_ref),
         :ok <- ensure_equal(:attach_grant_ref, grant.attach_grant_ref, envelope.attach_grant_ref),
         :ok <-
           ensure_equal(
             :target_auth_posture_ref,
             posture.target_auth_posture_ref,
             grant.target_auth_posture_ref
           ),
         :ok <-
           ensure_equal(
             :target_auth_posture_ref,
             posture.target_auth_posture_ref,
             envelope.target_auth_posture_ref
           ),
         :ok <-
           ensure_equal(
             :boundary_session_id,
             posture.boundary_session_id,
             envelope.boundary_session_id
           ),
         :ok <-
           ensure_equal(
             :boundary_session_id,
             posture.boundary_session_id,
             grant.boundary_session_id
           ),
         :ok <- ensure_equal(:workspace_ref, posture.workspace_ref, envelope.workspace_ref),
         :ok <- ensure_equal(:workspace_ref, posture.workspace_ref, grant.workspace_ref),
         :ok <-
           ensure_equal(
             :no_egress_posture_ref,
             posture.no_egress_posture_ref,
             envelope.no_egress_posture_ref
           ),
         :ok <-
           ensure_equal(
             :no_egress_posture_ref,
             posture.no_egress_posture_ref,
             grant.no_egress_posture_ref
           ),
         :ok <-
           ensure_equal(
             :process_target_identity_ref,
             posture.process_target_identity_ref,
             envelope.process_target_identity_ref
           ),
         :ok <-
           ensure_equal(
             :process_target_identity_ref,
             posture.process_target_identity_ref,
             grant.process_target_identity_ref
           ),
         :ok <-
           ensure_equal(
             :stream_target_identity_ref,
             posture.stream_target_identity_ref,
             envelope.stream_target_identity_ref
           ),
         :ok <-
           ensure_equal(
             :stream_target_identity_ref,
             posture.stream_target_identity_ref,
             grant.stream_target_identity_ref
           ),
         :ok <-
           ensure_allowed(
             :allowed_attach_grant_refs,
             [grant.attach_grant_ref],
             posture.allowed_attach_grant_refs
           ),
         :ok <-
           ensure_allowed(
             :credential_handle_refs,
             envelope.credential_handle_refs,
             grant.credential_handle_refs
           ),
         :ok <-
           ensure_allowed(
             :allowed_credential_handle_refs,
             envelope.credential_handle_refs,
             posture.allowed_credential_handle_refs
           ) do
      {:ok, authorization_evidence(posture, grant, envelope)}
    end
  end

  @spec cleanup_event(t() | map() | keyword(), atom() | String.t()) :: map()
  def cleanup_event(posture, reason) do
    posture = new!(posture)

    %{
      contract_version: @contract_version,
      tenant_ref: posture.tenant_ref,
      target_ref: posture.target_ref,
      target_auth_posture_ref: posture.target_auth_posture_ref,
      cleanup_reason: to_string(reason),
      cleanup_refs: posture.cleanup_refs,
      materialized_state_refs: [],
      raw_material_present?: false
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      tenant_ref: Contracts.fetch_required_stringish!(attrs, :tenant_ref),
      target_ref: fetch_required_ref!(attrs, :target_ref, "target://"),
      target_kind: Contracts.fetch_required_stringish!(attrs, :target_kind),
      target_auth_posture:
        attrs
        |> Contracts.fetch_required_stringish!(:target_auth_posture)
        |> normalize_posture!(),
      target_auth_posture_ref:
        fetch_required_ref!(attrs, :target_auth_posture_ref, "target-posture://"),
      boundary_session_id: Contracts.fetch_required_stringish!(attrs, :boundary_session_id),
      workspace_ref: fetch_required_ref!(attrs, :workspace_ref, "workspace://"),
      no_egress_posture_ref:
        fetch_required_ref!(attrs, :no_egress_posture_ref, "no-egress-posture://"),
      process_target_identity_ref:
        fetch_optional_ref!(attrs, :process_target_identity_ref, "process-target-identity://"),
      stream_target_identity_ref:
        fetch_optional_ref!(attrs, :stream_target_identity_ref, "stream-target-identity://"),
      service_identity_ref:
        fetch_optional_ref!(attrs, :service_identity_ref, "service-identity://"),
      allowed_provider_families: fetch_optional_string_list!(attrs, :allowed_provider_families),
      allowed_provider_account_refs:
        fetch_optional_ref_list!(attrs, :allowed_provider_account_refs, "provider-account://"),
      allowed_connector_instance_refs:
        fetch_optional_ref_list!(attrs, :allowed_connector_instance_refs, "connector-instance://"),
      allowed_credential_handle_refs:
        fetch_optional_credential_handle_refs!(attrs, :allowed_credential_handle_refs),
      allowed_attach_grant_refs:
        fetch_optional_ref_list!(attrs, :allowed_attach_grant_refs, "attach-grant://"),
      cleanup_refs: fetch_optional_ref_list!(attrs, :cleanup_refs, "cleanup://"),
      materialized_state_refs:
        fetch_optional_ref_list!(attrs, :materialized_state_refs, "materialized-credential://"),
      multi_handle?: Contracts.fetch_optional_boolean!(attrs, :multi_handle?, false)
    }
  end

  defp normalize_posture!(posture) do
    case Map.fetch(@posture_aliases, posture) do
      {:ok, normalized} ->
        normalized

      :error ->
        raise ArgumentError, "target_auth_posture is not supported: #{inspect(posture)}"
    end
  end

  defp fetch_required_ref!(attrs, key, prefix) do
    attrs
    |> Contracts.fetch_required_stringish!(key)
    |> validate_ref_prefix!(to_string(key), prefix)
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

  defp fetch_optional_credential_handle_refs!(attrs, key) do
    Contracts.fetch_optional_list!(attrs, key, [], &validate_credential_handle_ref!/1)
  end

  defp fetch_optional_string_list!(attrs, key) do
    Contracts.fetch_optional_list!(
      attrs,
      key,
      [],
      &Contracts.validate_non_empty_string!(&1, to_string(key))
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

  defp ensure_posture_allows_credentials(%__MODULE__{target_auth_posture: "forbidden"}, _handles),
    do: {:error, :target_posture_forbidden}

  defp ensure_posture_allows_credentials(%__MODULE__{target_auth_posture: posture}, handles)
       when posture in @credential_forbidden_postures and handles != [],
       do: {:error, :target_posture_forbids_credentials}

  defp ensure_posture_allows_credentials(_posture, _handles), do: :ok

  defp ensure_multi_handle(%__MODULE__{multi_handle?: false}, handles) when length(handles) > 1,
    do: {:error, :target_multi_handle_not_permitted}

  defp ensure_multi_handle(_posture, _handles), do: :ok

  defp ensure_equal(field, expected, actual) do
    if expected == actual do
      :ok
    else
      {:error, {mismatch_reason(field), expected, actual}}
    end
  end

  defp ensure_allowed(_field, _values, []), do: :ok

  defp ensure_allowed(field, values, allowed) do
    missing = Enum.reject(values, &(&1 in allowed))

    case missing do
      [] -> :ok
      _ -> {:error, {not_allowed_reason(field), missing}}
    end
  end

  defp mismatch_reason(:target_ref), do: :target_ref_mismatch
  defp mismatch_reason(:attach_grant_ref), do: :attach_grant_ref_mismatch
  defp mismatch_reason(:target_auth_posture_ref), do: :target_auth_posture_ref_mismatch
  defp mismatch_reason(:boundary_session_id), do: :boundary_session_id_mismatch
  defp mismatch_reason(:workspace_ref), do: :workspace_ref_mismatch
  defp mismatch_reason(:no_egress_posture_ref), do: :no_egress_posture_ref_mismatch
  defp mismatch_reason(:process_target_identity_ref), do: :process_target_identity_ref_mismatch
  defp mismatch_reason(:stream_target_identity_ref), do: :stream_target_identity_ref_mismatch

  defp not_allowed_reason(:allowed_attach_grant_refs), do: :attach_grant_ref_not_allowed
  defp not_allowed_reason(:credential_handle_refs), do: :credential_handle_ref_not_allowed
  defp not_allowed_reason(:allowed_credential_handle_refs), do: :credential_handle_ref_not_allowed

  defp authorization_evidence(posture, grant, envelope) do
    %{
      contract_version: @contract_version,
      tenant_ref: posture.tenant_ref,
      target_ref: posture.target_ref,
      target_auth_posture: posture.target_auth_posture,
      target_auth_posture_ref: posture.target_auth_posture_ref,
      attach_grant_ref: grant.attach_grant_ref,
      boundary_session_id: posture.boundary_session_id,
      workspace_ref: posture.workspace_ref,
      no_egress_posture_ref: posture.no_egress_posture_ref,
      process_target_identity_ref: posture.process_target_identity_ref,
      stream_target_identity_ref: posture.stream_target_identity_ref,
      credential_handle_refs: envelope.credential_handle_refs,
      cleanup_refs: posture.cleanup_refs,
      cleanup_required?: true,
      raw_material_present?: false
    }
  end

  defp stringify_contract(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), value} end)
  end
end
