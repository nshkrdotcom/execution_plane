defmodule ExecutionPlaneTest do
  use ExUnit.Case
  doctest ExecutionPlane

  test "returns the package identity" do
    assert ExecutionPlane.identity() == :execution_plane
  end
end
