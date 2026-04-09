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
      ContractFixtures.execution_failure_outcome()
    ]

    Enum.each(fixtures, fn fixture ->
      dumped = fixture.__struct__.dump(fixture)
      assert fixture.__struct__.new!(dumped) == fixture
    end)
  end
end
