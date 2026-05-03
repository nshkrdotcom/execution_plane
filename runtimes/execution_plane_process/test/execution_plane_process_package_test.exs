defmodule ExecutionPlaneProcessPackageTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Process.Transport.GuestBridge
  alias ExecutionPlane.Process.Transport.LowerSimulation
  alias ExecutionPlane.Process.Transport.Surface
  alias ExecutionPlane.Process.Transport.Surface.Capabilities

  test "starts the standalone process application supervisor" do
    assert {:ok, _apps} = Application.ensure_all_started(:execution_plane_process)
    assert Process.whereis(ExecutionPlane.TaskSupervisor)
  end

  test "runs a lower simulation through the process package" do
    assert {:ok, result} =
             ExecutionPlane.Process.run(
               %{
                 command: "ignored",
                 execution_surface: %{surface_kind: "local_subprocess"}
               },
               route: %{
                 resolved_target: %{
                   "lower_simulation" => %{
                     "scenario_ref" => "process-package-smoke",
                     "status" => "succeeded",
                     "raw_payload" => %{
                       "exit" => %{"code" => 0},
                       "stdout" => "ok",
                       "stderr" => ""
                     },
                     "no_egress_policy" => %{
                       "policy_ref" => "policy://process-package-smoke",
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
               },
               lineage: %{
                 idempotency_key: "process-package-smoke"
               }
             )

    assert result.outcome.status == "succeeded"
  end

  test "rejects local user switching on unprivileged hosts before spawning" do
    if unprivileged_host?() do
      assert {:error, result} =
               ExecutionPlane.Process.run(
                 %{
                   command: "true",
                   user: "nobody",
                   execution_surface: %{surface_kind: "local_subprocess"}
                 },
                 lineage: %{idempotency_key: "user-switch-preflight"}
               )

      assert result.outcome.status == "failed"
      assert result.outcome.failure.reason == "user switch requires privileged erlexec"
      assert result.outcome.raw_payload.user == "nobody"
      assert result.outcome.raw_payload.required_privilege == "root"
    end
  end

  test "process surface rejects unknown binary transport option keys" do
    options = %{"provider_supplied_key" => "unbounded"}

    assert {:error, {:invalid_transport_options, ^options}} =
             Surface.resolve(
               command: "cat",
               execution_surface: %{
                 "surface_kind" => :ssh_exec,
                 "transport_options" => options
               }
             )
  end

  test "process capabilities reject unknown atomish strings without runtime atom creation" do
    assert {:error, {:invalid_startup_kind, "provider_spawn"}} =
             Capabilities.new(%{"startup_kind" => "provider_spawn"})

    capabilities =
      Capabilities.new!(
        remote?: true,
        startup_kind: :bridge,
        path_semantics: :guest,
        supports_run?: true,
        supports_streaming_stdio?: true,
        supports_pty?: false,
        supports_user?: false,
        supports_env?: false,
        supports_cwd?: false,
        interrupt_kind: :rpc
      )

    refute Capabilities.satisfies_requirements?(capabilities, %{
             "startup_kind" => "provider_spawn"
           })
  end

  test "guest bridge rejects unknown binary transport option keys" do
    options = %{"provider_supplied_key" => "unbounded"}

    assert {:error, {:invalid_transport_options, ^options}} =
             GuestBridge.normalize_transport_options(options)
  end

  test "lower simulation rejects unknown binary transport option keys" do
    options = %{"provider_supplied_key" => "unbounded"}

    assert {:error, {:invalid_transport_options, ^options}} =
             LowerSimulation.normalize_transport_options(options)
  end

  defp unprivileged_host? do
    case :os.type() do
      {:unix, _name} ->
        case System.cmd("id", ["-u"], stderr_to_stdout: true) do
          {"0\n", 0} -> false
          {_uid, 0} -> true
          _other -> true
        end

      _other ->
        true
    end
  rescue
    _error -> true
  end
end
