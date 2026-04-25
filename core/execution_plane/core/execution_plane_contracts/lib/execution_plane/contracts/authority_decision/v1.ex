defmodule ExecutionPlane.Contracts.AuthorityDecision.V1 do
  @moduledoc """
  Packet-local Brain contract baseline carried across the lower stack.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:authority_decision_v1)

  defstruct [
    :contract_version,
    :decision_id,
    :tenant_id,
    :request_id,
    :policy_version,
    :boundary_class,
    :trust_profile,
    :approval_profile,
    :egress_profile,
    :workspace_profile,
    :resource_profile,
    :decision_hash,
    extensions: %{}
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          decision_id: String.t(),
          tenant_id: String.t(),
          request_id: String.t(),
          policy_version: String.t(),
          boundary_class: String.t(),
          trust_profile: String.t(),
          approval_profile: String.t(),
          egress_profile: String.t(),
          workspace_profile: String.t(),
          resource_profile: String.t(),
          decision_hash: String.t(),
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
  def dump(%__MODULE__{} = decision) do
    %{
      "contract_version" => decision.contract_version,
      "decision_id" => decision.decision_id,
      "tenant_id" => decision.tenant_id,
      "request_id" => decision.request_id,
      "policy_version" => decision.policy_version,
      "boundary_class" => decision.boundary_class,
      "trust_profile" => decision.trust_profile,
      "approval_profile" => decision.approval_profile,
      "egress_profile" => decision.egress_profile,
      "workspace_profile" => decision.workspace_profile,
      "resource_profile" => decision.resource_profile,
      "decision_hash" => decision.decision_hash,
      "extensions" => Contracts.stringify_keys(decision.extensions)
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      decision_id: Contracts.fetch_required_stringish!(attrs, :decision_id),
      tenant_id: Contracts.fetch_required_stringish!(attrs, :tenant_id),
      request_id: Contracts.fetch_required_stringish!(attrs, :request_id),
      policy_version: Contracts.fetch_required_stringish!(attrs, :policy_version),
      boundary_class: Contracts.fetch_required_stringish!(attrs, :boundary_class),
      trust_profile: Contracts.fetch_required_stringish!(attrs, :trust_profile),
      approval_profile: Contracts.fetch_required_stringish!(attrs, :approval_profile),
      egress_profile: Contracts.fetch_required_stringish!(attrs, :egress_profile),
      workspace_profile: Contracts.fetch_required_stringish!(attrs, :workspace_profile),
      resource_profile: Contracts.fetch_required_stringish!(attrs, :resource_profile),
      decision_hash: Contracts.fetch_required_stringish!(attrs, :decision_hash),
      extensions: Contracts.normalize_extensions!(attrs)
    }
  end
end
