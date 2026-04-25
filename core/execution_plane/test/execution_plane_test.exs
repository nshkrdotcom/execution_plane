defmodule ExecutionPlaneTest do
  use ExUnit.Case
  doctest ExecutionPlane

  test "returns the package identity" do
    assert ExecutionPlane.identity() == :execution_plane
  end

  test "tracks the published package homes" do
    assert ExecutionPlane.package_homes().root_common == "."
    assert ExecutionPlane.package_homes().jsonrpc == "protocols/execution_plane_jsonrpc"
    assert ExecutionPlane.package_homes().node == "runtimes/execution_plane_node"
    assert ExecutionPlane.package_homes().process == "runtimes/execution_plane_process"
    assert ExecutionPlane.package_homes().websocket == "streaming/execution_plane_websocket"
  end

  test "names the final active mix projects" do
    assert ExecutionPlane.minimal_first_cut() ==
             [
               :execution_plane,
               :execution_plane_http,
               :execution_plane_jsonrpc,
               :execution_plane_sse,
               :execution_plane_websocket,
               :execution_plane_process,
               :execution_plane_node,
               :execution_plane_operator_terminal
             ]
  end
end
