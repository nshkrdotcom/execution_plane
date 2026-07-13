defmodule ExecutionPlaneProcessPackageTest.OSProbe do
  @behaviour ExecutionPlane.Process.OS

  @owner ExecutionPlaneProcessPackageTest.OSProbeOwner

  def privileged_user? do
    notify(:privileged_user_checked)
    true
  end

  def await(predicate, attempts, delay_ms) do
    notify({:await_called, attempts, delay_ms})
    _ = predicate.()
    {:ok, %{checks: 1, attempts_remaining: attempts, delay_ms: delay_ms}}
  end

  def signal_process_group(os_pid, signal) do
    notify({:signal_process_group, os_pid, signal})
    :ok
  end

  defp notify(message) do
    case Process.whereis(@owner) do
      pid when is_pid(pid) -> send(pid, message)
      _other -> :ok
    end
  end
end

defmodule ExecutionPlaneProcessPackageTest.UnprivilegedOS do
  @behaviour ExecutionPlane.Process.OS

  @owner ExecutionPlaneProcessPackageTest.OSProbeOwner

  def privileged_user? do
    notify(:privileged_user_checked)
    false
  end

  def await(_predicate, attempts, delay_ms) do
    notify({:await_called, attempts, delay_ms})
    {:ok, %{checks: 1, attempts_remaining: attempts, delay_ms: delay_ms}}
  end

  def signal_process_group(os_pid, signal) do
    notify({:signal_process_group, os_pid, signal})
    :ok
  end

  defp notify(message) do
    case Process.whereis(@owner) do
      pid when is_pid(pid) -> send(pid, message)
      _other -> :ok
    end
  end
end

defmodule ExecutionPlaneProcessPackageTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Command
  alias ExecutionPlane.Process.Transport.GuestBridge
  alias ExecutionPlane.Process.Transport.LowerSimulation
  alias ExecutionPlane.Process.Transport.Options
  alias ExecutionPlane.Process.Transport.Subprocess
  alias ExecutionPlane.Process.Transport.Surface
  alias ExecutionPlane.Process.Transport.Surface.Capabilities
  alias ExecutionPlane.Process.Transport.TaggedRelay
  alias ExecutionPlane.Process.TransportSupervisor
  alias ExecutionPlane.Runtimes.Process, as: ProcessRuntime
  alias ExecutionPlane.TaskSupport
  alias ExecutionPlaneProcessPackageTest.OSProbe
  alias ExecutionPlaneProcessPackageTest.UnprivilegedOS

  test "starts the standalone process application supervisor" do
    expected_app =
      if Application.spec(:execution_plane_process),
        do: :execution_plane_process,
        else: :execution_plane

    assert Enum.any?(Application.started_applications(), fn {app, _description, _version} ->
             app == expected_app
           end)

    assert Process.whereis(ExecutionPlane.TaskSupervisor)
    assert Process.whereis(TransportSupervisor)

    owner = self()
    assert {:ok, _pid} = TaskSupport.start_child(fn -> send(owner, :standalone_task_started) end)

    assert {:ok, _pid} =
             TransportSupervisor.start_child(
               Task,
               fn -> send(owner, :standalone_transport_child_started) end
             )

    assert_receive :standalone_task_started, 250
    assert_receive :standalone_transport_child_started, 250
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

  test "process runtime rejects user switching through injected OS preflight" do
    with_os_probe_owner(fn ->
      assert {:error, {:user_switch_requires_privilege, "nobody"}} =
               ProcessRuntime.run(command: "true", user: "nobody", os: UnprivilegedOS)

      assert_receive :privileged_user_checked, 250
      refute_receive {:await_called, _attempts, _delay_ms}, 100
    end)
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

  test "subprocess child start accepts normalized transport options" do
    with_os_probe_owner(fn ->
      assert {:ok, options} =
               Options.new(
                 command: "/bin/sleep",
                 args: ["1"],
                 startup_mode: :eager,
                 headless_timeout_ms: 5_000,
                 os: OSProbe
               )

      assert options.os == OSProbe
      assert {:ok, pid} = Subprocess.start_link(options)
      assert_receive {:await_called, 20, 50}, 1_000
      assert Process.alive?(pid)

      assert :ok = Subprocess.close(pid)
      assert_receive {:signal_process_group, os_pid, "KILL"}, 1_000
      assert is_integer(os_pid)
    end)
  end

  test "subprocess public keyword start_link routes through transport supervisor" do
    assert Process.whereis(TransportSupervisor)

    assert {:ok, pid} =
             Subprocess.start_link(
               command: "/bin/sleep",
               args: ["1"],
               headless_timeout_ms: 5_000
             )

    assert supervised_transport_child?(pid)
    assert :ok = Subprocess.close(pid)
  end

  test "guest bridge exposes normalized child specs for supervisor ownership" do
    assert {:ok, options} =
             Options.new(command: "ignored", surface_kind: :guest_bridge, transport_options: [])

    assert %{
             id: GuestBridge,
             start: {GuestBridge, :start_link, [^options]},
             restart: :temporary,
             type: :worker
           } = GuestBridge.child_spec(options)
  end

  test "tagged relay exposes child specs for supervisor ownership" do
    ref = make_ref()

    opts = [
      core_event_tag: :core,
      core_ref: ref,
      public_event_tag: :public,
      event_mapper: &List.wrap/1
    ]

    assert %{
             id: TaggedRelay,
             start: {TaggedRelay, :start_link, [{owner, ^ref, ^opts}]},
             restart: :temporary,
             type: :worker
           } = TaggedRelay.child_spec({self(), ref, opts})

    assert owner == self()
  end

  test "transport options reject invalid OS boundary modules" do
    assert {:error, {:invalid_transport_options, {:invalid_os, String}}} =
             Options.new(command: "true", os: String)
  end

  test "subprocess interrupt and force close use injected OS signal boundary" do
    with_os_probe_owner(fn ->
      assert {:ok, pid} =
               Subprocess.start(
                 command: "/bin/sleep",
                 args: ["5"],
                 os: OSProbe,
                 headless_timeout_ms: 5_000
               )

      assert_receive {:await_called, 20, 50}, 1_000
      assert :ok = Subprocess.interrupt(pid)
      assert_receive {:signal_process_group, os_pid, "INT"}, 1_000
      assert is_integer(os_pid)

      assert :ok = Subprocess.force_close(pid)
      assert_receive {:signal_process_group, ^os_pid, "KILL"}, 1_000
    end)
  end

  test "subprocess one-shot timeout uses injected OS signal boundary" do
    with_os_probe_owner(fn ->
      command = Command.new("/bin/sleep", ["1"])

      assert {:error, {:transport, error}} = Subprocess.run(command, timeout: 0, os: OSProbe)
      assert error.reason == :timeout
      assert_receive {:await_called, 20, 50}, 1_000
      assert_receive {:signal_process_group, os_pid, "TERM"}, 1_000
      assert is_integer(os_pid)
    end)
  end

  test "process runtime timeout uses injected OS signal boundary" do
    with_os_probe_owner(fn ->
      assert {:error, {:timeout, _context}} =
               ProcessRuntime.run(command: "/bin/sleep", argv: ["1"], timeout: 0, os: OSProbe)

      assert_receive {:await_called, 20, 50}, 1_000
      assert_receive {:signal_process_group, os_pid, "TERM"}, 1_000
      assert is_integer(os_pid)
    end)
  end

  test "supervised subprocess transports are not restarted after normal command exit" do
    assert Process.whereis(TransportSupervisor)

    ref = make_ref()

    assert {:ok, pid} =
             Subprocess.start(
               command: "/bin/sh",
               args: ["-c", "printf '%s\\n' transport_once"],
               subscriber: {self(), ref},
               event_tag: :transport_restart_test
             )

    assert_receive {:transport_restart_test, ^ref, {:message, "transport_once"}}, 1_000
    assert_receive {:transport_restart_test, ^ref, {:exit, exit}}, 1_000
    assert exit.status == :success

    refute_receive {:transport_restart_test, ^ref, _event}, 100
    refute Process.alive?(pid)
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

  defp with_os_probe_owner(fun) do
    Process.register(self(), ExecutionPlaneProcessPackageTest.OSProbeOwner)

    try do
      fun.()
    after
      if Process.whereis(ExecutionPlaneProcessPackageTest.OSProbeOwner) == self() do
        Process.unregister(ExecutionPlaneProcessPackageTest.OSProbeOwner)
      end
    end
  end

  defp supervised_transport_child?(pid) do
    TransportSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.any?(fn {_id, child_pid, :worker, _modules} -> child_pid == pid end)
  end

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
