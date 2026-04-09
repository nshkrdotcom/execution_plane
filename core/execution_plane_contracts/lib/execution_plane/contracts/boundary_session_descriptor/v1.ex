defmodule ExecutionPlane.Contracts.BoundarySessionDescriptor.V1 do
  @moduledoc """
  Durable Spine-owned boundary/session descriptor.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:boundary_session_descriptor_v1)

  defstruct [
    :contract_version,
    :boundary_session_id,
    :decision_id,
    :session_status,
    :attach_state,
    :workspace_ref,
    artifact_refs: [],
    lease_refs: [],
    approval_refs: [],
    policy_echo: %{},
    extensions: %{}
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          boundary_session_id: String.t(),
          decision_id: String.t(),
          session_status: String.t(),
          attach_state: String.t(),
          workspace_ref: String.t(),
          artifact_refs: [String.t()],
          lease_refs: [String.t()],
          approval_refs: [String.t()],
          policy_echo: map(),
          extensions: map()
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
  def dump(%__MODULE__{} = descriptor) do
    %{
      "contract_version" => descriptor.contract_version,
      "boundary_session_id" => descriptor.boundary_session_id,
      "decision_id" => descriptor.decision_id,
      "session_status" => descriptor.session_status,
      "attach_state" => descriptor.attach_state,
      "workspace_ref" => descriptor.workspace_ref,
      "artifact_refs" => descriptor.artifact_refs,
      "lease_refs" => descriptor.lease_refs,
      "approval_refs" => descriptor.approval_refs,
      "policy_echo" => Contracts.stringify_keys(descriptor.policy_echo),
      "extensions" => Contracts.stringify_keys(descriptor.extensions)
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      boundary_session_id: Contracts.fetch_required_stringish!(attrs, :boundary_session_id),
      decision_id: Contracts.fetch_required_stringish!(attrs, :decision_id),
      session_status: Contracts.fetch_required_stringish!(attrs, :session_status),
      attach_state: Contracts.fetch_required_stringish!(attrs, :attach_state),
      workspace_ref: Contracts.fetch_required_stringish!(attrs, :workspace_ref),
      artifact_refs:
        Contracts.fetch_optional_list!(
          attrs,
          :artifact_refs,
          [],
          &Contracts.validate_non_empty_string!(&1, "artifact_ref")
        ),
      lease_refs:
        Contracts.fetch_optional_list!(
          attrs,
          :lease_refs,
          [],
          &Contracts.validate_non_empty_string!(&1, "lease_ref")
        ),
      approval_refs:
        Contracts.fetch_optional_list!(
          attrs,
          :approval_refs,
          [],
          &Contracts.validate_non_empty_string!(&1, "approval_ref")
        ),
      policy_echo: Contracts.fetch_optional_map!(attrs, :policy_echo, %{}),
      extensions: Contracts.normalize_extensions!(attrs)
    }
  end
end
