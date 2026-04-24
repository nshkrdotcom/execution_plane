defmodule ExecutionPlaneTest do
  use ExUnit.Case
  doctest ExecutionPlane

  test "returns the package identity" do
    assert ExecutionPlane.identity() == :execution_plane
  end

  test "tracks the published package homes" do
    assert ExecutionPlane.package_homes().contracts == "core/execution_plane_contracts"
    assert ExecutionPlane.package_homes().jsonrpc == "protocols/execution_plane_jsonrpc"
    assert ExecutionPlane.package_homes().websocket == "streaming/execution_plane_websocket"
  end

  test "names the minimal executable substrate roles" do
    assert ExecutionPlane.minimal_first_cut() ==
             [:contracts, :kernel, :http, :jsonrpc, :local, :process, :testkit]
  end
end
