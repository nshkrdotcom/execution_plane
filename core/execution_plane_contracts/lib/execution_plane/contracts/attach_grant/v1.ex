defmodule ExecutionPlane.Contracts.AttachGrant.V1 do
  @moduledoc """
  Ephemeral attach grant emitted by the Spine and consumed by facade/session layers.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:attach_grant_v1)

  defstruct [
    :contract_version,
    :boundary_session_id,
    :attach_mode,
    :working_directory,
    :expires_at,
    attach_surface: %{},
    granted_capabilities: []
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          boundary_session_id: String.t(),
          attach_mode: String.t(),
          attach_surface: map(),
          working_directory: String.t() | nil,
          expires_at: String.t(),
          granted_capabilities: [String.t()]
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
    %{
      "contract_version" => grant.contract_version,
      "boundary_session_id" => grant.boundary_session_id,
      "attach_mode" => grant.attach_mode,
      "attach_surface" => Contracts.stringify_keys(grant.attach_surface),
      "working_directory" => grant.working_directory,
      "expires_at" => grant.expires_at,
      "granted_capabilities" => grant.granted_capabilities
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      boundary_session_id: Contracts.fetch_required_stringish!(attrs, :boundary_session_id),
      attach_mode: Contracts.fetch_required_stringish!(attrs, :attach_mode),
      attach_surface: Contracts.fetch_optional_map!(attrs, :attach_surface, %{}),
      working_directory: Contracts.fetch_optional_stringish!(attrs, :working_directory),
      expires_at:
        attrs
        |> Contracts.fetch_required_stringish!(:expires_at)
        |> Contracts.validate_iso8601!("expires_at"),
      granted_capabilities:
        Contracts.fetch_optional_list!(
          attrs,
          :granted_capabilities,
          [],
          &Contracts.validate_non_empty_string!(&1, "granted_capability")
        )
    }
  end
end
