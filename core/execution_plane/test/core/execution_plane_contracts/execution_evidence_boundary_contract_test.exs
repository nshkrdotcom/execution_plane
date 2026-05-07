defmodule ExecutionPlane.Contracts.ExecutionEvidenceBoundaryContractTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.ExecutionEvidenceBoundary.V1, as: ExecutionEvidenceBoundary
  alias ExecutionPlane.Contracts.ExecutionOutcome.V1, as: ExecutionOutcome
  alias ExecutionPlane.Testkit.ContractFixtures

  test "boundary projects bounded evidence from ExecutionOutcome.v1 without narrowing raw_payload" do
    outcome =
      ExecutionOutcome.new!(%{
        route_id: ContractFixtures.execution_route().route_id,
        status: "succeeded",
        family: "http",
        raw_payload: %{
          "status_code" => 200,
          "headers" => %{"content-type" => "application/json"},
          "body" => "raw provider body kept in ExecutionOutcome.v1 only"
        },
        artifacts: [],
        metrics: %{},
        lineage: ContractFixtures.lineage(route_id: ContractFixtures.execution_route().route_id)
      })

    boundary =
      ExecutionEvidenceBoundary.from_outcome!(outcome,
        lower_simulation_evidence: ContractFixtures.lower_simulation_evidence()
      )

    assert outcome.raw_payload["body"] == "raw provider body kept in ExecutionOutcome.v1 only"
    assert boundary.contract_version == "ExecutionPlane.ExecutionEvidenceBoundary.v1"
    assert boundary.owner_repo == "execution_plane"
    assert boundary.bounded_status == "succeeded"

    assert boundary.persistence_posture.persistence_profile_ref ==
             "persistence-profile://mickey_mouse"

    assert boundary.persistence_posture.raw_process_state_persistence? == false

    assert String.contains?(
             boundary.input_fingerprint_ref,
             "fingerprint://execution-plane/input/"
           )

    assert boundary.scan_result["status"] == "passed"

    dump = ExecutionEvidenceBoundary.dump(boundary)

    assert dump["bounded_exit_code_or_response_shape"]["raw_payload_shape"] == [
             "body",
             "headers",
             "status_code"
           ]

    assert dump["persistence_posture"]["component"] == :execution_evidence
    assert dump["persistence_posture"]["durable?"] == false
    assert dump["persistence_posture"]["raw_process_state_persistence?"] == false

    refute String.contains?(inspect(dump), "raw provider body kept")
    refute Map.has_key?(dump, "raw_payload")
  end

  test "boundary can emit durable storage posture without persisting raw outcome payload" do
    outcome = ContractFixtures.execution_outcome()

    boundary =
      ExecutionEvidenceBoundary.from_outcome!(outcome,
        lower_simulation_evidence: ContractFixtures.lower_simulation_evidence(),
        persistence_posture: %{
          persistence_profile_ref: "persistence-profile://ops_durable",
          persistence_tier_ref: "persistence-tier://postgres_shared",
          capture_level_ref: "capture-level://audit_only",
          store_set_ref: "store-set://ops_primary",
          store_partition_ref: "store-partition://postgres_shared/default",
          retention_policy_ref: "retention://postgres_shared",
          persistence_receipt_ref: "persistence-receipt://execution-plane/evidence/ops",
          store_ref: "store://postgres_shared",
          durable?: true,
          restart_durability_claim: :durable_restart,
          raw_process_state_persistence?: true
        }
      )

    assert boundary.persistence_posture.component == :execution_evidence

    assert boundary.persistence_posture.persistence_profile_ref ==
             "persistence-profile://ops_durable"

    assert boundary.persistence_posture.durable? == true
    assert boundary.persistence_posture.raw_process_state_persistence? == false

    dump = ExecutionEvidenceBoundary.dump(boundary)

    assert dump["persistence_posture"]["durable?"] == true
    assert dump["persistence_posture"]["raw_process_state_persistence?"] == false
    refute String.contains?(inspect(dump), "raw provider body kept")
    refute Map.has_key?(dump, "raw_payload")
  end

  test "boundary rejects raw prompt, provider body, secret, and semantic body persistence" do
    base = ExecutionEvidenceBoundary.dump(ContractFixtures.execution_evidence_boundary())

    for {key, value} <- [
          {"prompt", "raw prompt"},
          {"provider_body", "{\"wire\":true}"},
          {"secret", "sk-live"},
          {"semantic_body", String.duplicate("semantic ", 16)}
        ] do
      attrs = put_in(base, ["bounded_exit_code_or_response_shape", key], value)

      assert_error_contains("raw durable evidence", fn ->
        ExecutionEvidenceBoundary.new!(attrs)
      end)
    end
  end

  test "boundary rejects StackLab ownership and semantic provider policy" do
    base = ExecutionEvidenceBoundary.dump(ContractFixtures.execution_evidence_boundary())

    assert_error_contains("owner_repo must be execution_plane", fn ->
      ExecutionEvidenceBoundary.new!(Map.put(base, "owner_repo", "stack_lab"))
    end)

    for key <- ["provider_refs", "model_refs", "budget_profile_ref"] do
      assert_error_contains("provider or model or budget semantics", fn ->
        ExecutionEvidenceBoundary.new!(Map.put(base, key, ["forbidden"]))
      end)
    end
  end

  test "ExecutionOutcome.v1 source still carries raw_payload as raw map, not boundary shape" do
    source =
      File.read!(
        "core/execution_plane_contracts/lib/execution_plane/contracts/execution_outcome/v1.ex"
      )

    assert String.contains?(source, "raw_payload: Contracts.fetch_optional_map!")
    refute String.contains?(source, "raw_payload_shape")
    refute String.contains?(source, "bounded_evidence_projection")
    refute String.contains?(source, "ExecutionEvidenceBoundary")
  end

  defp assert_error_contains(fragment, fun) do
    error = assert_raise(ArgumentError, fun)

    assert Exception.message(error)
           |> String.downcase()
           |> String.contains?(String.downcase(fragment))
  end
end
