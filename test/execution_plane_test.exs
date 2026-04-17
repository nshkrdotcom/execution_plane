defmodule ExecutionPlaneTest do
  use ExUnit.Case
  doctest ExecutionPlane

  test "returns the package identity" do
    assert ExecutionPlane.identity() == :execution_plane
  end

  test "tracks the frozen package homes" do
    assert ExecutionPlane.package_homes().contracts == "core/execution_plane_contracts"
    assert ExecutionPlane.package_homes().jsonrpc == "protocols/execution_plane_jsonrpc"

    assert ExecutionPlane.package_homes().operator_terminal ==
             "runtimes/execution_plane_operator_terminal"

    assert ExecutionPlane.package_homes().microvm == "sandboxes/execution_plane_microvm"
  end

  test "names the Wave 1 minimal first cut" do
    assert ExecutionPlane.minimal_first_cut() ==
             [:contracts, :kernel, :http, :jsonrpc, :local, :process, :testkit]
  end
end
