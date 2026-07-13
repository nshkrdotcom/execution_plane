defmodule ExecutionPlane.Contracts.LowerSimulationScenarioContractTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.AdapterSelectionPolicy.V1, as: AdapterSelectionPolicy
  alias ExecutionPlane.Contracts.ExecutionOutcome.V1, as: ExecutionOutcome
  alias ExecutionPlane.Contracts.LowerSimulationEvidence.V1, as: LowerSimulationEvidence
  alias ExecutionPlane.Contracts.LowerSimulationScenario.V1, as: LowerSimulationScenario
  alias ExecutionPlane.Testkit.ContractFixtures

  test "lower simulation scenario round-trips with Phase 6 enum enforcement" do
    scenario = LowerSimulationScenario.new!(scenario_attrs())
    dump = LowerSimulationScenario.dump(scenario)

    assert scenario.contract_version == "ExecutionPlane.LowerSimulationScenario.v1"
    assert scenario.owner_repo == "execution_plane"
    assert scenario.protocol_surface == "http"
    assert scenario.matcher_class == "deterministic_over_input"

    assert dump["bounded_evidence_projection"]["contract_version"] ==
             LowerSimulationEvidence.contract_version()

    assert_json_safe(dump)
    assert LowerSimulationScenario.new!(dump) == scenario
  end

  test "lower simulation scenario rejects non-Execution Plane ownership and bad enums" do
    assert_error_contains(["owner_repo", "execution_plane"], fn ->
      LowerSimulationScenario.new!(scenario_attrs(%{owner_repo: "jido_integration"}))
    end)

    assert_error_contains(["protocol_surface", "unsupported"], fn ->
      LowerSimulationScenario.new!(scenario_attrs(%{protocol_surface: "provider"}))
    end)

    assert_error_contains(["matcher_class", "unsupported"], fn ->
      LowerSimulationScenario.new!(scenario_attrs(%{matcher_class: "semantic_provider"}))
    end)
  end

  test "lower simulation scenario rejects semantic provider policy in Execution Plane" do
    assert_error_contains(["semantic provider policy", "Execution Plane"], fn ->
      LowerSimulationScenario.new!(Map.put(scenario_attrs(), :provider_refs, ["openai"]))
    end)

    assert_error_contains(["semantic provider policy", "Execution Plane"], fn ->
      LowerSimulationScenario.new!(Map.put(scenario_attrs(), "budget_profile_ref", "budget://1"))
    end)
  end

  test "lower simulation scenario rejects egress, raw evidence, and raw-payload narrowing" do
    assert_error_contains(["no_egress_assertion", "external_egress", "deny"], fn ->
      LowerSimulationScenario.new!(
        scenario_attrs(%{no_egress_assertion: %{"external_egress" => "allow"}})
      )
    end)

    assert_error_contains(["bounded_evidence_projection", "raw_payload_persistence"], fn ->
      LowerSimulationScenario.new!(
        scenario_attrs(%{
          bounded_evidence_projection: %{
            "contract_version" => LowerSimulationEvidence.contract_version(),
            "raw_payload_persistence" => "raw_body"
          }
        })
      )
    end)

    assert_error_contains(["ExecutionOutcome.v1.raw_payload", "must not be narrowed"], fn ->
      LowerSimulationScenario.new!(
        scenario_attrs(%{
          bounded_evidence_projection: %{
            "contract_version" => LowerSimulationEvidence.contract_version(),
            "target_contract" => "ExecutionOutcome.v1.raw_payload",
            "raw_payload_persistence" => "shape_only"
          }
        })
      )
    end)
  end

  test "adapter selection policy uses owner registries and rejects request simulation selectors" do
    policy = AdapterSelectionPolicy.new!(adapter_policy_attrs())
    dump = AdapterSelectionPolicy.dump(policy)

    assert policy.contract_version == "ExecutionPlane.AdapterSelectionPolicy.v1"
    assert policy.selection_surface == "adapter_registry"
    assert policy.owner_repo == "execution_plane"
    assert_json_safe(dump)
    assert AdapterSelectionPolicy.new!(dump) == policy

    assert_error_contains("public simulation selector", fn ->
      AdapterSelectionPolicy.new!(Map.put(adapter_policy_attrs(), :simulation, "service_mode"))
    end)

    assert_error_contains(["config_key", "public simulation selector"], fn ->
      AdapterSelectionPolicy.new!(adapter_policy_attrs(%{config_key: "request.simulation"}))
    end)
  end

  test "ExecutionOutcome.v1 raw_payload remains raw while wrapper carries bounded evidence" do
    outcome =
      ExecutionOutcome.new!(%{
        route_id: ContractFixtures.execution_route().route_id,
        status: "succeeded",
        family: "http",
        raw_payload: %{"body" => "raw provider body kept in outcome", "status_code" => 200},
        artifacts: [],
        metrics: %{},
        lineage: ContractFixtures.lineage(route_id: ContractFixtures.execution_route().route_id)
      })

    assert outcome.raw_payload["body"] == "raw provider body kept in outcome"

    evidence = ContractFixtures.lower_simulation_evidence()
    dump = LowerSimulationEvidence.dump(evidence)

    assert dump["raw_payload_shape"] == ["body", "headers", "status_code"]
    refute Map.has_key?(dump["input_fingerprint"], "body")
  end

  defp scenario_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        scenario_id: "lower-scenario://execution-plane/http/success",
        version: "1.0.0",
        owner_repo: "execution_plane",
        route_kind: "execution_route",
        protocol_surface: "http",
        matcher_class: "deterministic_over_input",
        status_or_exit_or_response_or_stream_or_chunk_or_fault_shape: %{
          "status" => "succeeded",
          "raw_payload_shape" => ["body", "headers", "status_code"]
        },
        no_egress_assertion: %{
          "external_egress" => "deny",
          "process_spawn" => "deny",
          "side_effect_result" => "not_attempted"
        },
        bounded_evidence_projection: %{
          "contract_version" => LowerSimulationEvidence.contract_version(),
          "raw_payload_persistence" => "shape_only",
          "fingerprints" => ["input", "output"]
        },
        input_fingerprint_ref: "fingerprint://execution-plane/input/sha256",
        cleanup_behavior: %{
          "runtime_artifacts" => "delete",
          "durable_payload" => "deny_raw"
        }
      },
      overrides
    )
  end

  defp adapter_policy_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        selection_surface: "adapter_registry",
        owner_repo: "execution_plane",
        config_key: "execution_plane.lower_runtime.adapter_registry",
        default_value_when_unset: "normal_lower_runtime",
        fail_closed_action_when_misconfigured: "reject_route_install"
      },
      overrides
    )
  end

  defp assert_json_safe(value) when is_binary(value) or is_boolean(value) or is_nil(value),
    do: :ok

  defp assert_json_safe(value) when is_integer(value) or is_float(value), do: :ok

  defp assert_json_safe(value) when is_list(value) do
    Enum.each(value, &assert_json_safe/1)
  end

  defp assert_json_safe(value) when is_map(value) do
    assert Enum.all?(Map.keys(value), &is_binary/1)
    Enum.each(value, fn {_key, nested} -> assert_json_safe(nested) end)
  end

  defp assert_error_contains(fragments, fun) do
    error = assert_raise(ArgumentError, fun)
    message = Exception.message(error) |> String.downcase()

    fragments
    |> List.wrap()
    |> Enum.each(fn fragment ->
      assert String.contains?(message, String.downcase(fragment))
    end)
  end
end
