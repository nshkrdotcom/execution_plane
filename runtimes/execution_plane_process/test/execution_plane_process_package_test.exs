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
               route: lower_simulation_route("process-package-smoke"),
               lineage: lineage("process-package-smoke")
             )

    assert result.outcome.status == "succeeded"
  end

  test "governed process intents clear ambient env by default" do
    with_restored_env("EXECUTION_PLANE_ENV05_SECRET", "ambient-env05-secret", fn ->
      assert {:ok, result} =
               ExecutionPlane.Process.run(
                 %{
                   command: "ignored",
                   execution_surface: %{surface_kind: "local_subprocess"}
                 },
                 envelope: governed_envelope(),
                 route: lower_simulation_route("governed-process-env-default"),
                 lineage: lineage("governed-process-env-default")
               )

      assert result.plan.intent.clear_env == true
      assert result.plan.intent.env_projection == %{}
      refute String.contains?(inspect(result), "ambient-env05-secret")
    end)
  end

  test "governed process intents project only explicit env materialization" do
    with_restored_env("EXECUTION_PLANE_ENV05_TOKEN", "ambient-token", fn ->
      assert {:ok, result} =
               ExecutionPlane.Process.run(
                 %{
                   command: "ignored",
                   env: %{"LEASE_TOKEN" => "explicit-lease-token"},
                   execution_surface: %{surface_kind: "local_subprocess"}
                 },
                 envelope: governed_envelope(),
                 route: lower_simulation_route("governed-process-explicit-env"),
                 lineage: lineage("governed-process-explicit-env")
               )

      assert result.plan.intent.clear_env == true
      assert result.plan.intent.env_projection == %{"LEASE_TOKEN" => "explicit-lease-token"}
      refute Map.has_key?(result.plan.intent.env_projection, "EXECUTION_PLANE_ENV05_TOKEN")
      refute String.contains?(inspect(result), "ambient-token")
    end)
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

  test "process surface rejects non-binary lower-runtime refs with bounded errors" do
    assert {:error, {:invalid_target_id, 123}} =
             Surface.resolve(
               command: "cat",
               execution_surface: %{"surface_kind" => :local_subprocess, "target_id" => 123}
             )

    assert {:error, {:invalid_lease_ref, 123}} =
             Surface.resolve(
               command: "cat",
               execution_surface: %{"surface_kind" => :local_subprocess, "lease_ref" => 123}
             )

    assert {:error, {:invalid_surface_ref, 123}} =
             Surface.resolve(
               command: "cat",
               execution_surface: %{"surface_kind" => :local_subprocess, "surface_ref" => 123}
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

  defp governed_envelope do
    [
      lease_ref: "lease://env-05-process",
      credential_handle_refs: ["credential-handle://tenant-1/env-05-process"],
      route_template_ref: "route-template://env-05-process",
      extensions: %{authority_packet_ref: "authority-packet://env-05-process"}
    ]
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

  defp lineage(ref), do: %{idempotency_key: ref}

  defp with_restored_env(key, value, fun) do
    previous = System.get_env(key)
    System.put_env(key, value)

    try do
      fun.()
    after
      case previous do
        nil -> System.delete_env(key)
        previous_value -> System.put_env(key, previous_value)
      end
    end
  end
end
