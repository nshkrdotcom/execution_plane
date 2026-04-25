defmodule ExecutionPlane.Node.LocalWeakVerifier do
  @moduledoc """
  Stub local verifier for the honest same-node process class.

  This verifier mints only `local-erlexec-weak`. Hosts use it for local
  in-process process Targets; stronger isolation requires a different verifier
  and a different attested Target.
  """

  @behaviour ExecutionPlane.Target.Verifier

  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.Target.Attestation
  alias ExecutionPlane.Target.Descriptor

  @class "local-erlexec-weak"
  @type_name "local-erlexec-weak"

  @impl true
  def verifier_id, do: "execution-plane:local-weak-verifier:v1"

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

    if Map.get(evidence, "signature") in [nil, ""] do
      {:error,
       Rejection.new(
         :target_attestation_unverifiable,
         "local weak target attestation requires a verifier signature"
       )}
    else
      {:ok,
       Descriptor.new!(
         target_id:
           Keyword.get(opts, :target_id, Map.get(evidence, "target_id", "local-erlexec")),
         lane_id: Keyword.get(opts, :lane_id, Map.get(evidence, "lane_id", "process")),
         attested_capability_classes: [@class],
         verifier_id: verifier_id(),
         attestation_id: attestation.attestation_id,
         attested_at: attestation.presented_at,
         metadata: %{"local" => true},
         signature: Map.fetch!(evidence, "signature")
       )}
    end
  end

  def mint_attestation(opts \\ []) do
    Attestation.new!(
      attestation_id: ExecutionPlane.Boundary.stable_id("att-local"),
      attestation_type: @type_name,
      presented_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      claimed_capability_classes: [@class],
      evidence: %{
        "class" => @class,
        "target_id" => Keyword.get(opts, :target_id, "local-erlexec"),
        "lane_id" => Keyword.get(opts, :lane_id, "process"),
        "signature" => Keyword.get(opts, :signature, "local-weak-stub-signature")
      }
    )
  end
end
