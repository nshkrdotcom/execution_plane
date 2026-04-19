defmodule ExecutionPlane.Contracts.ContractPacketTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Testkit.ContractFixtures

  test "every Wave 1 contract module exposes a stable v1 contract_version" do
    assert Enum.all?(Contracts.contract_modules(), fn module ->
             function_exported?(module, :contract_version, 0) and
               String.ends_with?(module.contract_version(), ".v1")
           end)
  end

  test "the fixture packet round-trips through dump/new!" do
    fixtures = [
      ContractFixtures.authority_decision(),
      ContractFixtures.boundary_session_descriptor(),
      ContractFixtures.execution_intent_envelope(),
      ContractFixtures.http_execution_intent(),
      ContractFixtures.process_execution_intent(),
      ContractFixtures.jsonrpc_execution_intent(),
      ContractFixtures.execution_route(),
      ContractFixtures.attach_grant(),
      ContractFixtures.credential_handle_ref(),
      ContractFixtures.execution_event(),
      ContractFixtures.execution_outcome(),
      ContractFixtures.execution_failure_outcome(),
      ContractFixtures.stream_backpressure(),
      ContractFixtures.worker_budget(),
      ContractFixtures.no_bypass_scan(),
      ContractFixtures.stream_attach_revocation()
    ]

    Enum.each(fixtures, fn fixture ->
      dumped = fixture.__struct__.dump(fixture)
      assert fixture.__struct__.new!(dumped) == fixture
    end)
  end

  test "handoff and raw fact helpers stay canonical" do
    assert Contracts.handoff_statuses() == [:accepted, :rejected, :unknown]
    assert Contracts.local_spool_modes() == [:disabled, :emergency_only]
    assert Contracts.handoff_receipt_id("route-1", "handoff-1") == "receipt:route-1:handoff-1"
    assert Contracts.pressure_fact_id("route-1", "lane-1", 0) == "pressure:route-1:lane-1:0"
    assert Contracts.reconnect_fact_id("route-1", "lane-1", 2) == "reconnect:route-1:lane-1:2"

    assert Contracts.lane_churn_fact_id("route-1", "lane-1", 3) ==
             "lane_churn:route-1:lane-1:3"
  end
end
