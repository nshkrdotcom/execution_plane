defmodule ExecutionPlane.Node.LocalHTTPWeakVerifier do
  @moduledoc """
  Verifier for HTTP effects performed by the runtime node's local HTTP lane.

  `local-http-weak` is honest about its isolation: the HTTP lifecycle is owned
  by the separately configured runtime node, but it is not a sandbox, guest,
  or microVM claim. Descriptors are pinned to the HTTP lane and cannot satisfy
  process admission.
  """

  @behaviour ExecutionPlane.Target.Verifier

  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.Target.Attestation
  alias ExecutionPlane.Target.Descriptor

  @class "local-http-weak"
  @type_name "local-http-weak"

  @impl true
  def verifier_id, do: "execution-plane:local-http-weak-verifier:v1"

  @impl true
  def attestation_types, do: [@type_name]

  @impl true
  def capability_classes, do: [@class]

  @impl true
  def handles?(attestation) do
    attestation = Attestation.new!(attestation)
    attestation.attestation_type == @type_name
  end

  @impl true
  def verify(attestation, opts) do
    attestation = Attestation.new!(attestation)
    evidence = attestation.evidence || %{}

    cond do
      Map.get(evidence, "signature") in [nil, ""] ->
        {:error,
         Rejection.new(
           :target_attestation_unverifiable,
           "local weak HTTP target attestation requires a verifier signature"
         )}

      Map.get(evidence, "lane_id", "http") != "http" ->
        {:error,
         Rejection.new(
           :target_attestation_unverifiable,
           "local weak HTTP target attestation must be pinned to lane_id=http"
         )}

      true ->
        {:ok,
         Descriptor.new!(
           target_id: Keyword.get(opts, :target_id, Map.get(evidence, "target_id", "local-http")),
           lane_id: "http",
           attested_capability_classes: [@class],
           verifier_id: verifier_id(),
           attestation_id: attestation.attestation_id,
           attested_at: attestation.presented_at,
           metadata: %{"local" => true, "effect_family" => "http"},
           signature: Map.fetch!(evidence, "signature")
         )}
    end
  end

  def mint_attestation(opts \\ []) do
    Attestation.new!(
      attestation_id: ExecutionPlane.Boundary.stable_id("att-local-http"),
      attestation_type: @type_name,
      presented_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      claimed_capability_classes: [@class],
      evidence: %{
        "class" => @class,
        "target_id" => Keyword.get(opts, :target_id, "local-http"),
        "lane_id" => "http",
        "signature" => Keyword.get(opts, :signature, "local-http-weak-stub-signature")
      }
    )
  end
end
