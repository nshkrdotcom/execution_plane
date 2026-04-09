defmodule ExecutionPlane.Placements.PlacementFamilyTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Placements.{Guest, Local, SSH, Surface}

  test "placement helpers map the supported surface kinds without overstating isolation" do
    assert Local.supported_surface_kinds() == ["local_subprocess"]
    assert SSH.supported_surface_kinds() == ["ssh_exec"]
    assert Guest.supported_surface_kinds() == ["guest_bridge"]

    assert Local.supports_surface?(Surface.new!(surface_kind: "local_subprocess"))
    assert SSH.supports_surface?(Surface.new!(surface_kind: "ssh_exec"))
    assert Guest.supports_surface?(Surface.new!(surface_kind: "guest_bridge"))

    refute SSH.supports_surface?(Surface.new!(surface_kind: "local_subprocess"))
    refute Guest.supports_surface?(Surface.new!(surface_kind: "ssh_exec"))
  end
end
