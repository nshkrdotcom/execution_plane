defmodule ExecutionPlaneReleaseArtifactTest do
  use ExUnit.Case, async: false

  @repo_root Path.expand("../../../../..", __DIR__)
  @artifact_root Path.join(@repo_root, "dist/monolith/execution_plane")

  alias ExecutionPlane.Process.TransportSupervisor
  alias ExecutionPlane.Protocols.JsonRpc.Adapter

  test "projection selects the frozen three-project public distribution" do
    lock =
      @artifact_root
      |> Path.join("projection.lock.json")
      |> File.read!()
      |> Jason.decode!()

    assert lock["graph"]["selected_projects"] == [
             "core/execution_plane",
             "protocols/execution_plane_jsonrpc",
             "runtimes/execution_plane_process"
           ]

    assert lock["graph"]["excluded_projects"] == [
             ".",
             "protocols/execution_plane_http",
             "runtimes/execution_plane_node",
             "runtimes/execution_plane_operator_terminal",
             "streaming/execution_plane_sse",
             "streaming/execution_plane_websocket"
           ]

    assert lock["graph"]["violations"] == []
  end

  test "generated dependency graph is canonical and contains no component packages" do
    mix_source = File.read!(Path.join(@artifact_root, "mix.exs"))

    dependencies =
      ~r/{:(\w+),\s*"([^"]+)"/
      |> Regex.scan(mix_source, capture: :all_but_first)
      |> Map.new(fn [app, requirement] -> {app, requirement} end)

    assert dependencies == %{
             "credo" => "~> 1.7",
             "dialyxir" => "~> 1.4",
             "erlexec" => "~> 2.3",
             "ex_doc" => "~> 0.40",
             "ground_plane_contracts" => "~> 0.1.0",
             "ground_plane_persistence_policy" => "~> 0.1.0",
             "jason" => "~> 1.4",
             "telemetry" => "~> 1.3"
           }

    refute Regex.match?(~r/[\s\[,](?:path|git|github):\s/, mix_source)
    refute mix_source =~ ":execution_plane_jsonrpc"
    refute mix_source =~ ":execution_plane_process"
  end

  test "generated application preserves only the process wrapper and exact runtime children" do
    assert Application.spec(:execution_plane, :mod) == {ExecutionPlane.Application, []}

    assert [
             {{"runtimes/execution_plane_process", ExecutionPlane.Process.Application},
              wrapper_pid, :supervisor, [ExecutionPlane.Process.Application]}
           ] = Supervisor.which_children(ExecutionPlane.Application.Supervisor)

    assert wrapper_pid == Process.whereis(ExecutionPlane.Process.Supervisor)

    runtime_children = Supervisor.which_children(ExecutionPlane.Process.Supervisor)

    assert runtime_children
           |> Enum.map(fn {id, _pid, _type, _modules} -> id end)
           |> MapSet.new() ==
             MapSet.new([ExecutionPlane.TaskSupervisor, TransportSupervisor])

    assert Process.whereis(ExecutionPlane.TaskSupervisor)
    assert Process.whereis(TransportSupervisor)
  end

  test "generated application module manifest contains selected and excludes separate modules" do
    modules = Application.spec(:execution_plane, :modules) |> MapSet.new()

    assert MapSet.subset?(
             MapSet.new([
               ExecutionPlane.Application,
               ExecutionPlane.Boundary,
               ExecutionPlane.Process.Transport,
               ExecutionPlane.Protocols.JsonRpc.Adapter
             ]),
             modules
           )

    Enum.each(
      [
        ExecutionPlane.HTTP,
        ExecutionPlane.Node,
        ExecutionPlane.OperatorTerminal,
        ExecutionPlane.SSE,
        ExecutionPlane.WebSocket
      ],
      fn excluded -> refute MapSet.member?(modules, excluded) end
    )
  end

  test "every generated source module has one definition and package files exclude caches" do
    module_occurrences =
      @artifact_root
      |> Path.join("lib/**/*.ex")
      |> Path.wildcard()
      |> Enum.flat_map(&modules_in_file/1)
      |> Enum.frequencies()

    assert module_occurrences != %{}
    assert Enum.all?(module_occurrences, fn {_module, count} -> count == 1 end)

    lock =
      @artifact_root
      |> Path.join("projection.lock.json")
      |> File.read!()
      |> Jason.decode!()

    package_files = lock["projection"]["package_files"]
    copied_files = lock["projection"]["copied_files"]

    assert "lib" in package_files
    assert "projection.lock.json" in package_files

    refute Enum.any?(copied_files, fn path ->
             path =~ "/plts/" or path =~ "/_build/" or path =~ "/deps/" or
               String.ends_with?(path, [".beam", ".plt", ".plt.hash"])
           end)
  end

  test "clean consumer exercises JSON-RPC framing and local process simulation" do
    assert {:ok, state, []} = Adapter.init(request_id_start: 7)

    assert {:ok, 7, frame, next_state} =
             Adapter.encode_request(%{method: "health", params: %{probe: true}}, state)

    assert Jason.decode!(frame) == %{
             "id" => 7,
             "method" => "health",
             "params" => %{"probe" => true}
           }

    assert {:ok, [{:response, 7, {:ok, %{"healthy" => true}}}], ^next_state} =
             Adapter.handle_inbound(~s({"id":7,"result":{"healthy":true}}), next_state)

    assert {:ok, result} =
             ExecutionPlane.Process.run(
               %{
                 command: "ignored",
                 execution_surface: %{surface_kind: "local_subprocess"}
               },
               route: lower_simulation_route("release-consumer"),
               lineage: %{idempotency_key: "release-consumer"}
             )

    assert result.outcome.status == "succeeded"
  end

  defp modules_in_file(path) do
    path
    |> File.read!()
    |> Code.string_to_quoted!()
    |> Macro.prewalk([], fn
      {:defmodule, _, [module_ast, _]} = node, modules ->
        {node, [Macro.to_string(module_ast) | modules]}

      node, modules ->
        {node, modules}
    end)
    |> elem(1)
  end

  defp lower_simulation_route(ref) do
    %{
      resolved_target: %{
        "lower_simulation" => %{
          "scenario_ref" => ref,
          "status" => "succeeded",
          "raw_payload" => %{
            "exit" => %{"code" => 0},
            "stdout" => "ok",
            "stderr" => ""
          },
          "no_egress_policy" => %{
            "policy_ref" => "policy://#{ref}",
            "owner_repo" => "execution_plane",
            "mode" => "deny",
            "enforcement_boundary" => "lower_runtime",
            "denied_surfaces" => %{
              "external_egress" => "deny",
              "process_spawn" => "deny",
              "unregistered_provider_route" => "deny",
              "raw_external_saas_write_path" => "deny"
            },
            "required_negative_evidence" => [
              "attempted_unregistered_provider_route",
              "attempted_raw_external_saas_write_path"
            ]
          }
        }
      }
    }
  end
end
