defmodule ExecutionPlane.Placements.SurfaceContractTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Placements.Capabilities
  alias ExecutionPlane.Placements.Surface

  test "helper lookups preserve the narrow placement vocabulary" do
    assert {:ok, capabilities} = Surface.capabilities("local_subprocess")
    assert capabilities.remote? == false
    assert capabilities.path_semantics == :local

    assert Surface.path_semantics("ssh_exec") == :remote
    assert Surface.path_semantics(%{"surface_kind" => "guest_bridge"}) == :guest
    assert Surface.nonlocal_path_surface?("local_subprocess") == false
    assert Surface.nonlocal_path_surface?("ssh_exec") == true
    assert Surface.nonlocal_path_surface?(%{"surface_kind" => "guest_bridge"}) == true
    assert Surface.remote_surface?("ssh_exec") == true
  end

  test "new/1 accepts canonical execution_surface inputs and strips launch fields" do
    assert {:ok, surface} =
             Surface.new(%{
               "contract_version" => "execution_surface.v1",
               "surface_kind" => "ssh_exec",
               "target_id" => "ssh-target-1",
               "boundary_class" => "remote_cli",
               "observability" => %{"suite" => "contract"},
               "transport_options" => %{
                 "destination" => "ssh.example",
                 "command" => "cat",
                 "cwd" => "/tmp/ignored"
               }
             })

    assert surface.contract_version == "execution_surface.v1"
    assert surface.surface_kind == "ssh_exec"
    assert surface.target_id == "ssh-target-1"
    assert surface.boundary_class == "remote_cli"

    assert Surface.to_map(surface) == %{
             "contract_version" => "execution_surface.v1",
             "surface_kind" => "ssh_exec",
             "transport_options" => %{"destination" => "ssh.example"},
             "target_id" => "ssh-target-1",
             "lease_ref" => nil,
             "surface_ref" => nil,
             "boundary_class" => "remote_cli",
             "observability" => %{"suite" => "contract"}
           }
  end

  test "new/1 rejects unsupported execution-surface contract versions" do
    assert {:error, {:invalid_contract_version, "execution_surface.v0"}} =
             Surface.new(contract_version: "execution_surface.v0")
  end

  test "capabilities reject unknown atomish strings without runtime atom creation" do
    assert {:error, {:invalid_capabilities, {:startup_kind, "provider_spawn"}}} =
             Capabilities.new(%{"startup_kind" => "provider_spawn"})
  end
end
