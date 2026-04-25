defmodule ExecutionPlane.Contracts.NoEgressPolicyContractTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.NoEgressPolicy.V1, as: NoEgressPolicy
  alias ExecutionPlane.Testkit.ContractFixtures

  test "policy requires both Phase 6 negative evidence paths" do
    policy = ContractFixtures.no_egress_policy()
    dump = NoEgressPolicy.dump(policy)

    assert policy.contract_version == "ExecutionPlane.NoEgressPolicy.v1"
    assert policy.owner_repo == "execution_plane"
    assert policy.mode == "deny"

    assert "attempted_unregistered_provider_route" in policy.required_negative_evidence
    assert "attempted_raw_external_saas_write_path" in policy.required_negative_evidence
    assert dump["denied_surfaces"]["external_egress"] == "deny"
    assert NoEgressPolicy.new!(dump) == policy
  end

  test "policy rejects allow rules, missing negatives, and semantic policy" do
    base = NoEgressPolicy.dump(ContractFixtures.no_egress_policy())

    assert_raise ArgumentError, ~r/denied_surfaces.external_egress.*deny/, fn ->
      NoEgressPolicy.new!(put_in(base, ["denied_surfaces", "external_egress"], "allow"))
    end

    assert_raise ArgumentError, ~r/required_negative_evidence/, fn ->
      NoEgressPolicy.new!(
        Map.put(base, "required_negative_evidence", ["attempted_unregistered_provider_route"])
      )
    end

    assert_raise ArgumentError, ~r/provider or model or budget semantics/i, fn ->
      NoEgressPolicy.new!(Map.put(base, "budget_profile_ref", "budget://phase6"))
    end
  end
end
