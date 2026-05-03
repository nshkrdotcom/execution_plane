defmodule ExecutionPlane.OperatorTerminal.SurfaceTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.OperatorTerminal.Surface

  test "new/1 normalizes the operator-terminal family contract" do
    assert {:ok, %Surface{} = surface} =
             Surface.new(
               contract_version: "operator_terminal_surface.v1",
               surface_kind: :ssh_terminal,
               surface_ref: "operator-ssh-1",
               boundary_class: "operator_ui",
               transport_options: %{port: 2222},
               observability: %{suite: :operator_terminal}
             )

    assert surface.surface_kind == :ssh_terminal
    assert surface.surface_ref == "operator-ssh-1"
    assert surface.transport_options == [port: 2222]
    assert Surface.remote_surface?(surface)

    assert Surface.to_map(surface) == %{
             contract_version: "operator_terminal_surface.v1",
             surface_kind: :ssh_terminal,
             transport_options: %{port: 2222},
             surface_ref: "operator-ssh-1",
             boundary_class: "operator_ui",
             observability: %{suite: :operator_terminal}
           }
  end

  test "supported surface kinds stay distinct from workload process surfaces" do
    assert Surface.supported_surface_kinds() == [
             :local_terminal,
             :ssh_terminal,
             :distributed_terminal
           ]

    refute :local_subprocess in Surface.supported_surface_kinds()
    refute :ssh_exec in Surface.supported_surface_kinds()
  end

  test "new/1 accepts nested operator-terminal surface attrs from API opts" do
    assert {:ok, %Surface{} = surface} =
             Surface.new(
               operator_terminal_surface: %{
                 "surface_kind" => "distributed_terminal",
                 "surface_ref" => "operator-dist-1",
                 "transport_options" => %{"name" => "ops_listener"}
               }
             )

    assert surface.surface_kind == :distributed_terminal
    assert surface.surface_ref == "operator-dist-1"
    assert surface.transport_options == [name: "ops_listener"]
  end

  test "new/1 rejects unknown binary transport option keys" do
    options = %{"operator_supplied_key" => "unbounded"}

    assert {:error, {:invalid_transport_options, ^options}} =
             Surface.new(
               operator_terminal_surface: %{
                 "surface_kind" => "local_terminal",
                 "transport_options" => options
               }
             )
  end
end
