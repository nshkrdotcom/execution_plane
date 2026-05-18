defmodule ExecutionPlane.Contracts.BoundaryCodecTest do
  use ExUnit.Case, async: true

  test "ExecutionPlane boundary codec delegates deterministic hashes to GroundPlane" do
    left = %{tenant_id: "tenant-a", payload: %{b: 2, a: 1}}
    right = %{"payload" => %{"a" => 1, "b" => 2}, "tenant_id" => "tenant-a"}

    assert ExecutionPlane.Codec.encode!(left) ==
             ~s({"payload":{"a":1,"b":2},"tenant_id":"tenant-a"})

    assert ExecutionPlane.Codec.digest(left) == ExecutionPlane.Codec.digest(right)
    assert String.starts_with?(ExecutionPlane.Codec.digest(left), "sha256:")
  end
end
