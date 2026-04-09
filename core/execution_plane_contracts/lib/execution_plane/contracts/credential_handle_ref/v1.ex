defmodule ExecutionPlane.Contracts.CredentialHandleRef.V1 do
  @moduledoc """
  Reference to short-lived execution-time secret or workload identity material.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:credential_handle_ref_v1)

  defstruct [
    :contract_version,
    :handle_ref,
    :kind,
    :audience,
    :expires_at,
    :rotation_policy
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          handle_ref: String.t(),
          kind: String.t(),
          audience: String.t(),
          expires_at: String.t() | nil,
          rotation_policy: String.t() | nil
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
  def dump(%__MODULE__{} = handle) do
    %{
      "contract_version" => handle.contract_version,
      "handle_ref" => handle.handle_ref,
      "kind" => handle.kind,
      "audience" => handle.audience,
      "expires_at" => handle.expires_at,
      "rotation_policy" => handle.rotation_policy
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)
    expires_at = Contracts.fetch_optional_stringish!(attrs, :expires_at)

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      handle_ref: Contracts.fetch_required_stringish!(attrs, :handle_ref),
      kind: Contracts.fetch_required_stringish!(attrs, :kind),
      audience: Contracts.fetch_required_stringish!(attrs, :audience),
      expires_at:
        if(is_nil(expires_at),
          do: nil,
          else: Contracts.validate_iso8601!(expires_at, "expires_at")
        ),
      rotation_policy: Contracts.fetch_optional_stringish!(attrs, :rotation_policy)
    }
  end
end
