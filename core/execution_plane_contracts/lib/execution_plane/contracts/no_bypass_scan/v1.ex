defmodule ExecutionPlane.Contracts.NoBypassScan.V1 do
  @moduledoc """
  Source-boundary proof that hazmat Execution Plane APIs are not imported by public code.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:no_bypass_scan_v1)
  @scan_statuses ["clear", "blocked"]

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
    :scan_ref,
    :caller_repo,
    :forbidden_module,
    :required_facade,
    :violation_ref,
    :scan_status,
    checked_paths: [],
    violations: []
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
  def dump(%__MODULE__{} = scan) do
    scan
    |> Map.from_struct()
    |> Map.update!(:violations, &Contracts.stringify_keys/1)
    |> stringify_contract()
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)
    {principal_ref, system_actor_ref} = Contracts.fetch_required_actor_refs!(attrs)
    scan_status = Contracts.fetch_required_stringish!(attrs, :scan_status)
    checked_paths = Contracts.fetch_required_list!(attrs, :checked_paths, &validate_path!/1)
    violations = Contracts.fetch_optional_list!(attrs, :violations, [], &validate_violation!/1)

    unless scan_status in @scan_statuses do
      raise ArgumentError, "scan_status is not supported: #{inspect(scan_status)}"
    end

    validate_scan_semantics!(scan_status, violations)

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
      scan_ref: Contracts.fetch_required_stringish!(attrs, :scan_ref),
      caller_repo: Contracts.fetch_required_stringish!(attrs, :caller_repo),
      forbidden_module: Contracts.fetch_required_stringish!(attrs, :forbidden_module),
      required_facade: Contracts.fetch_required_stringish!(attrs, :required_facade),
      violation_ref: Contracts.fetch_required_stringish!(attrs, :violation_ref),
      scan_status: scan_status,
      checked_paths: checked_paths,
      violations: violations
    }
  end

  defp validate_scan_semantics!("clear", []), do: :ok
  defp validate_scan_semantics!("blocked", [_ | _]), do: :ok

  defp validate_scan_semantics!("clear", _violations) do
    raise ArgumentError, "clear no-bypass scan must not carry violations"
  end

  defp validate_scan_semantics!("blocked", _violations) do
    raise ArgumentError, "blocked no-bypass scan must carry at least one violation"
  end

  defp validate_path!(value), do: Contracts.validate_non_empty_string!(value, "checked_path")

  defp validate_violation!(value) when is_map(value) do
    value = Contracts.stringify_keys(value)

    Enum.each(["path", "line", "forbidden_module", "required_facade"], fn key ->
      case Map.fetch(value, key) do
        {:ok, line} when key == "line" and is_integer(line) and line > 0 ->
          :ok

        {:ok, field_value} when key != "line" ->
          Contracts.validate_non_empty_string!(field_value, "violation.#{key}")

        _other ->
          raise ArgumentError, "violation.#{key} is required"
      end
    end)

    value
  end

  defp validate_violation!(value) do
    raise ArgumentError, "violation must be a map, got: #{inspect(value)}"
  end

  defp stringify_contract(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), value} end)
  end
end
