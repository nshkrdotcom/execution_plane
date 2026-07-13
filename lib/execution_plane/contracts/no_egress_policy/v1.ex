defmodule ExecutionPlane.Contracts.NoEgressPolicy.V1 do
  @moduledoc """
  Fail-closed no-egress policy for lower-runtime simulation boundaries.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:no_egress_policy_v1)
  @owner_repo "execution_plane"
  @mode "deny"
  @required_negative_evidence [
    "attempted_unregistered_provider_route",
    "attempted_raw_external_saas_write_path"
  ]
  @required_denied_surfaces [
    "external_egress",
    "process_spawn",
    "unregistered_provider_route",
    "raw_external_saas_write_path"
  ]
  @forbidden_semantic_keys [
    :provider_refs,
    :model_refs,
    :budget_profile_ref,
    :meter_profile_ref,
    :semantic_policy,
    :cost_policy
  ]

  defstruct [
    :contract_version,
    :policy_ref,
    :owner_repo,
    :mode,
    :enforcement_boundary,
    :denied_surfaces,
    :required_negative_evidence
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          policy_ref: String.t(),
          owner_repo: String.t(),
          mode: String.t(),
          enforcement_boundary: String.t(),
          denied_surfaces: map(),
          required_negative_evidence: [String.t()]
        }

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec default_lower_boundary_policy!() :: t()
  def default_lower_boundary_policy! do
    new!(%{
      policy_ref: "no-egress-policy://execution-plane/lower/v1",
      owner_repo: @owner_repo,
      mode: @mode,
      enforcement_boundary: "lower_runtime",
      denied_surfaces: Map.new(@required_denied_surfaces, &{&1, "deny"}),
      required_negative_evidence: @required_negative_evidence
    })
  end

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
  def dump(%__MODULE__{} = policy) do
    %{
      "contract_version" => policy.contract_version,
      "policy_ref" => policy.policy_ref,
      "owner_repo" => policy.owner_repo,
      "mode" => policy.mode,
      "enforcement_boundary" => policy.enforcement_boundary,
      "denied_surfaces" => Contracts.stringify_keys(policy.denied_surfaces),
      "required_negative_evidence" => policy.required_negative_evidence
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)
    reject_semantic_provider_policy!(attrs)

    denied_surfaces =
      attrs
      |> Contracts.fetch_required_map!(:denied_surfaces)
      |> Contracts.stringify_keys()
      |> validate_denied_surfaces!()

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      policy_ref:
        Contracts.validate_opaque_handle_ref!(
          Contracts.fetch_required_stringish!(attrs, :policy_ref),
          "policy_ref"
        ),
      owner_repo: validate_owner_repo!(Contracts.fetch_required_stringish!(attrs, :owner_repo)),
      mode: validate_mode!(Contracts.fetch_required_stringish!(attrs, :mode)),
      enforcement_boundary: Contracts.fetch_required_stringish!(attrs, :enforcement_boundary),
      denied_surfaces: denied_surfaces,
      required_negative_evidence: validate_required_negative_evidence!(attrs)
    }
  end

  defp validate_owner_repo!(@owner_repo), do: @owner_repo

  defp validate_owner_repo!(owner_repo) do
    raise ArgumentError, "owner_repo must be #{@owner_repo}, got: #{inspect(owner_repo)}"
  end

  defp validate_mode!(@mode), do: @mode

  defp validate_mode!(mode) do
    raise ArgumentError, "mode must be #{@mode}, got: #{inspect(mode)}"
  end

  defp validate_denied_surfaces!(surfaces) do
    Enum.each(@required_denied_surfaces, fn surface ->
      unless Map.get(surfaces, surface) == "deny" do
        raise ArgumentError, "denied_surfaces.#{surface} must be deny"
      end
    end)

    surfaces
  end

  defp validate_required_negative_evidence!(attrs) do
    values =
      attrs
      |> Contracts.fetch_required_list!(:required_negative_evidence, fn value ->
        Contracts.validate_non_empty_string!(value, "required_negative_evidence")
      end)
      |> Enum.uniq()
      |> Enum.sort()

    expected = Enum.sort(@required_negative_evidence)

    if values == expected do
      values
    else
      raise ArgumentError,
            "required_negative_evidence must be #{inspect(expected)}, got: #{inspect(values)}"
    end
  end

  defp reject_semantic_provider_policy!(attrs) do
    if Enum.any?(@forbidden_semantic_keys, &has_key?(attrs, &1)) do
      raise ArgumentError, "NoEgressPolicy must not carry provider or model or budget semantics"
    end
  end

  defp has_key?(attrs, key),
    do: Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key))
end
