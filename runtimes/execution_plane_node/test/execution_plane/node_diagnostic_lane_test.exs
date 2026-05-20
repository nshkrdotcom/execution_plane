defmodule ExecutionPlane.NodeDiagnosticLaneTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Admission.Request
  alias ExecutionPlane.Node.LocalClient

  @server_name ExecutionPlane.NodeDiagnosticLaneTest.Server
  @node_id "execution-plane-diagnostic-node-test"

  setup do
    start_supervised!({ExecutionPlane.Node.Server, name: @server_name, node_id: @node_id})
    {:ok, server: @server_name}
  end

  test "diagnostic lane registers through the supervised node adapter registry", %{server: server} do
    assert :ok =
             ExecutionPlane.Node.register_lane(ExecutionPlane.Lanes.DiagnosticLane,
               server: server
             )

    request =
      Request.new!(
        lane_id: "diagnostic",
        operation: "diagnostic.echo",
        payload: %{"message" => "node-path"},
        provenance: ExecutionPlane.Provenance.direct_lower_lane_owner("diagnostic_lane_test")
      )

    assert {:ok, result} = LocalClient.execute(request, server: server)

    assert result.status == "succeeded"
    assert result.output["diagnostic_result"]["payload"]["message"] == "node-path"

    assert {:ok, descriptor} = LocalClient.describe(server: server)

    assert Enum.any?(descriptor.registered_lanes, fn lane ->
             lane["lane_id"] == "diagnostic" and lane["protocols"] == ["diagnostic"]
           end)
  end
end
