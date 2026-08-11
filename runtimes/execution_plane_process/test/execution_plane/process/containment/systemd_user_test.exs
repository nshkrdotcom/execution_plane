defmodule ExecutionPlane.Process.Containment.SystemdUserTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Process.Containment.SystemdUser

  test "unit names and environment inheritance are data, never shell text" do
    test_pid = self()

    runner = fn executable, argv, _opts ->
      send(test_pid, {:command, executable, argv})

      case executable do
        "systemctl" ->
          if "show-environment" in argv do
            {"", 0}
          else
            {"LoadState=loaded\nActiveState=active\nSubState=running\nResult=success\nControlGroup=\n",
             0}
          end

        "systemd-run" ->
          {"", 0}
      end
    end

    assert {:ok, handle} =
             SystemdUser.start("prompt-runner-test.service", "/bin/printf", ["$TOKEN; literal"],
               inherit_env: ["TOKEN"],
               command_runner: runner
             )

    assert handle.id == "prompt-runner-test.service"
    assert_received {:command, "systemd-run", args}
    assert "--setenv=TOKEN" in args
    assert List.last(args) == "$TOKEN; literal"
    refute Enum.any?(args, &String.contains?(&1, "TOKEN="))
  end

  test "invalid unit names are rejected before any command runs" do
    assert {:error, {:invalid_unit, "bad/unit"}} =
             SystemdUser.start("bad/unit", "/bin/true", [],
               command_runner: fn _program, _argv, _opts -> flunk("must not execute") end
             )
  end

  @tag :systemd_user
  test "stop kills a setsid descendant and proves the service cgroup empty" do
    if SystemdUser.available?() do
      root = Path.join(System.tmp_dir!(), "ep-containment-#{System.unique_integer([:positive])}")
      File.mkdir_p!(root)
      pid_file = Path.join(root, "child.pid")
      script = Path.join(root, "escape.sh")

      File.write!(script, "#!/bin/sh\nsetsid /bin/sleep 300 &\necho $! > \"$1\"\nwait\n")
      File.chmod!(script, 0o700)

      unit = "ep-containment-#{System.unique_integer([:positive])}.service"

      on_exit(fn ->
        _ = SystemdUser.stop(unit, timeout_ms: 5_000)
        File.rm_rf!(root)
      end)

      assert {:ok, handle} = SystemdUser.start(unit, script, [pid_file], cwd: root)
      child_pid = wait_for_pid(pid_file, 2_000)
      assert File.dir?("/proc/#{child_pid}")

      assert :ok = SystemdUser.stop(handle, timeout_ms: 5_000)
      assert {:ok, true} = SystemdUser.empty?(handle)
      refute File.dir?("/proc/#{child_pid}")
    end
  end

  @tag :systemd_user
  test "a command that completes before the first poll is a successful start" do
    if SystemdUser.available?() do
      unit = "ep-containment-quick-#{System.unique_integer([:positive])}.service"

      on_exit(fn -> _ = SystemdUser.stop(unit, timeout_ms: 5_000) end)

      assert {:ok, handle} = SystemdUser.start(unit, "/bin/true", [])
      assert {:ok, true} = SystemdUser.empty?(handle)
    end
  end

  defp wait_for_pid(path, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_for_pid(path, deadline)
  end

  defp do_wait_for_pid(path, deadline) do
    case File.read(path) do
      {:ok, contents} ->
        contents |> String.trim() |> String.to_integer()

      {:error, _reason} ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(20)
          do_wait_for_pid(path, deadline)
        else
          flunk("contained child never wrote pid file")
        end
    end
  end
end
