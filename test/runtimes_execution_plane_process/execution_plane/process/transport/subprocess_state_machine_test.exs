defmodule ExecutionPlane.Process.Transport.SubprocessStateMachineTest.OSProbe do
  @behaviour ExecutionPlane.Process.OS

  @owner ExecutionPlane.Process.Transport.SubprocessStateMachineTest.OSProbeOwner

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

defmodule ExecutionPlane.Process.Transport.SubprocessStateMachineTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Command
  alias ExecutionPlane.Process.Transport.Error
  alias ExecutionPlane.Process.Transport.Subprocess
  alias ExecutionPlane.Process.Transport.SubprocessStateMachineTest.OSProbe
  alias ExecutionPlane.ProcessExit

  @event_tag :subprocess_state_machine

  test "connects, streams lines, accepts eof, and shuts down cleanly" do
    assert {:ok, pid} =
             Subprocess.start(
               command: "/bin/cat",
               subscriber: {self(), ref = make_ref()},
               event_tag: @event_tag,
               headless_timeout_ms: 5_000
             )

    assert Subprocess.status(pid) == :connected

    assert :ok = Subprocess.send(pid, "alpha")
    assert_event(ref, {:message, "alpha"})

    assert :ok = Subprocess.send(pid, "beta\n")
    assert_event(ref, {:message, "beta"})

    assert :ok = Subprocess.end_input(pid)

    assert_receive {
                     @event_tag,
                     ^ref,
                     {:exit, %ProcessExit{status: :success, code: 0, stderr: ""}}
                   },
                   1_000

    assert_process_down(pid)
  end

  test "flushes stdout fragments and stderr before nonzero shutdown" do
    assert {:ok, pid} =
             Subprocess.start(
               command: "/bin/sh",
               args: ["-c", "printf crash_out; printf crash_err >&2; exit 7"],
               subscriber: {self(), ref = make_ref()},
               event_tag: @event_tag,
               headless_timeout_ms: 5_000
             )

    assert_event(ref, {:message, "crash_out"})
    assert_event(ref, {:stderr, "crash_err"})

    assert_receive {
                     @event_tag,
                     ^ref,
                     {:exit, %ProcessExit{status: :exit, code: 7, stderr: "crash_err"}}
                   },
                   1_000

    assert_process_down(pid)
  end

  test "overflow emits structured error and error exit before stopping" do
    assert {:ok, pid} =
             Subprocess.start(
               command: "/bin/sh",
               args: ["-c", "printf abcdefghi"],
               subscriber: {self(), ref = make_ref()},
               event_tag: @event_tag,
               max_buffer_size: 4,
               oversize_line_chunk_bytes: 4,
               max_recoverable_line_bytes: 8,
               headless_timeout_ms: 5_000
             )

    assert_receive {
                     @event_tag,
                     ^ref,
                     {:error, %Error{reason: {:buffer_overflow, actual_size, 8}} = error}
                   },
                   1_000

    assert actual_size > 8
    assert error.context.line_recovery_attempted? == true
    assert error.context.bytes_preserved == 8
    assert_receive {@event_tag, ^ref, {:exit, %ProcessExit{status: :error} = exit}}, 1_000
    assert exit.reason == {:buffer_overflow, 9, 8}
    assert_process_down(pid)
  end

  test "interrupt and force close use signal ownership from the OS boundary" do
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

  test "one-shot timeout records buffered output context and terminates process group" do
    with_os_probe_owner(fn ->
      command = Command.new("/bin/sh", ["-c", "printf before_timeout; sleep 2"])

      assert {:error, {:transport, %Error{} = error}} =
               Subprocess.run(command, timeout: 100, os: OSProbe)

      assert error.reason == :timeout
      assert error.context.command == "/bin/sh"
      assert error.context.args == ["-c", "printf before_timeout; sleep 2"]
      assert error.context.stdout == "before_timeout"
      assert error.context.output == "before_timeout"
      assert_receive {:await_called, 20, 50}, 1_000
      assert_receive {:signal_process_group, os_pid, "TERM"}, 1_000
      assert is_integer(os_pid)
    end)
  end

  defp assert_event(ref, expected) do
    assert_receive {@event_tag, ^ref, ^expected}, 1_000
  end

  defp assert_process_down(pid) when is_pid(pid) do
    monitor_ref = Process.monitor(pid)
    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, _reason}, 1_000
  end

  defp with_os_probe_owner(fun) do
    Process.register(
      self(),
      ExecutionPlane.Process.Transport.SubprocessStateMachineTest.OSProbeOwner
    )

    try do
      fun.()
    after
      owner = ExecutionPlane.Process.Transport.SubprocessStateMachineTest.OSProbeOwner

      if Process.whereis(owner) == self() do
        Process.unregister(owner)
      end
    end
  end
end
