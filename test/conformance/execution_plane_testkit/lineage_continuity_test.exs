defmodule ExecutionPlane.Testkit.LineageContinuityTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Testkit.ContractFixtures

  test "lineage stays continuous across route, event, and outcome fixtures" do
    route = ContractFixtures.execution_route()
    event = ContractFixtures.execution_event()
    outcome = ContractFixtures.execution_outcome()

    assert route.lineage.tenant_id == event.lineage.tenant_id
    assert route.lineage.request_id == event.lineage.request_id
    assert route.lineage.request_id == outcome.lineage.request_id
    assert route.lineage.decision_id == outcome.lineage.decision_id
    assert route.lineage.boundary_session_id == outcome.lineage.boundary_session_id
    assert route.route_id == event.route_id
    assert route.route_id == outcome.route_id
    assert event.lineage.event_id == event.event_id
  end

  test "attach grants and credential handle refs stay off raw long-lived secret carriage" do
    attach_grant = ContractFixtures.attach_grant()
    credential_handle_ref = ContractFixtures.credential_handle_ref()

    refute Map.has_key?(attach_grant.attach_surface, "secret")
    assert credential_handle_ref.handle_ref == "cred://1"
    assert credential_handle_ref.kind == "oauth_bearer"
  end
end
