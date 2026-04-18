defmodule ExecutionPlane.Testkit.LineageContinuityTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Testkit.ContractFixtures

  test "lineage stays continuous across route, event, and outcome fixtures" do
    route = ContractFixtures.execution_route()
    event = ContractFixtures.execution_event()
    outcome = ContractFixtures.execution_outcome()

    assert route.lineage.tenant_id == event.lineage.tenant_id
    assert route.lineage.trace_id == event.lineage.trace_id
    assert route.lineage.request_id == event.lineage.request_id
    assert route.lineage.trace_id == outcome.lineage.trace_id
    assert route.lineage.request_id == outcome.lineage.request_id
    assert route.lineage.decision_id == outcome.lineage.decision_id
    assert route.lineage.boundary_session_id == outcome.lineage.boundary_session_id
    assert route.route_id == event.route_id
    assert route.route_id == outcome.route_id
    assert event.lineage.event_id == event.event_id
  end

  test "missing lower trace_id is backfilled from request_id for one release cycle" do
    test_pid = self()
    handler_id = "execution-plane-trace-backfill-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:lower_gateway, :trace_id, :backfill],
      &__MODULE__.handle_trace_backfill/4,
      test_pid
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    route =
      ContractFixtures.lineage()
      |> Map.delete(:trace_id)
      |> then(fn lineage ->
        ExecutionPlane.Contracts.ExecutionRoute.V1.new!(%{
          route_id: "route-backfill-1",
          family: "http",
          protocol: "http",
          transport_family: "http",
          placement_family: "local",
          resolved_target: %{"target_id" => "loopback"},
          resolved_budget: %{"timeout_ms" => 5_000},
          lineage: Map.put(lineage, :route_id, "route-backfill-1")
        })
      end)

    assert route.lineage.trace_id == route.lineage.request_id

    assert_receive {:trace_id_backfill, %{count: 1},
                    %{
                      consumer: :execution_plane_contracts,
                      source: :request_id,
                      trace_id: trace_id,
                      tenant_id: "tenant-1",
                      request_id: request_id,
                      decision_id: "decision-1",
                      boundary_session_id: "boundary-session-1",
                      route_id: "route-backfill-1"
                    }},
                   1_000

    assert trace_id == request_id
  end

  test "attach grants and credential handle refs stay off raw long-lived secret carriage" do
    attach_grant = ContractFixtures.attach_grant()
    credential_handle_ref = ContractFixtures.credential_handle_ref()

    refute Map.has_key?(attach_grant.attach_surface, "secret")
    assert credential_handle_ref.handle_ref == "cred://1"
    assert credential_handle_ref.kind == "oauth_bearer"
  end

  def handle_trace_backfill(_event, measurements, metadata, pid) do
    send(pid, {:trace_id_backfill, measurements, metadata})
  end
end
