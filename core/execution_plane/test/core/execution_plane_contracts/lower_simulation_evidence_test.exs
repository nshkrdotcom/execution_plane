defmodule ExecutionPlane.Contracts.LowerSimulationEvidenceTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.LowerSimulationEvidence.V1, as: LowerSimulationEvidence
  alias ExecutionPlane.Testkit.ContractFixtures

  test "evidence records lower simulation proof without raw payload mutation" do
    evidence = ContractFixtures.lower_simulation_evidence()

    assert evidence.contract_version == "ExecutionPlane.LowerSimulationEvidence.v1"
    assert evidence.side_effect_policy == "deny_external_egress"
    assert evidence.side_effect_result == "not_attempted"
    assert evidence.raw_payload_shape == ["body", "headers", "status_code"]

    dumped = LowerSimulationEvidence.dump(evidence)

    refute Map.has_key?(dumped["input_fingerprint"], "body")
    refute Map.has_key?(dumped["output_fingerprint"], "body")
    assert dumped["outcome_contract_version"] == "execution_outcome.v1"
  end

  test "evidence rejects raw input material in fingerprints" do
    attrs =
      ContractFixtures.lower_simulation_evidence()
      |> LowerSimulationEvidence.dump()
      |> Map.put("input_fingerprint", %{
        "sha256" => "sha256:" <> String.duplicate("1", 64),
        "byte_size" => 1,
        "body" => "raw prompt"
      })

    assert {:error, %ArgumentError{} = error} = LowerSimulationEvidence.new(attrs)
    assert error.message =~ "input_fingerprint must not carry raw body"
  end

  test "evidence rejects route lineage mismatch" do
    attrs =
      ContractFixtures.lower_simulation_evidence()
      |> LowerSimulationEvidence.dump()
      |> put_in(["lineage", "route_id"], "route-other")

    assert {:error, %ArgumentError{} = error} = LowerSimulationEvidence.new(attrs)
    assert error.message =~ "route_id must match lineage.route_id"
  end
end
