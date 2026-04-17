defmodule ExecutionPlane.OperatorTerminalTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.OperatorTerminal
  alias ExecutionPlane.OperatorTerminal.TestSupport.App
  alias ExRatatui.{Event, Runtime}

  test "start_link/1 hosts a local operator terminal and exposes list/info state" do
    terminal_id = unique_terminal_id("ops-local")

    on_exit(fn ->
      assert OperatorTerminal.stop(terminal_id) in [:ok, {:error, :not_found}]
      :ok
    end)

    assert {:ok, terminal} =
             OperatorTerminal.start_link(
               mod: App,
               app_opts: [label: "local-terminal", test_mode: {40, 10}],
               surface_kind: :local_terminal,
               surface_ref: terminal_id,
               boundary_class: :operator_ui
             )

    assert %OperatorTerminal.Info{} = info = OperatorTerminal.info(terminal)
    assert info.terminal_id == terminal_id
    assert info.surface_kind == :local_terminal
    assert info.mod == App
    assert info.boundary_class == :operator_ui
    assert info.adapter_metadata == %{}

    assert Enum.any?(OperatorTerminal.list(), &(&1.terminal_id == terminal_id))

    assert :ok = OperatorTerminal.stop(terminal_id)
    refute Process.alive?(terminal)
  end

  test "normal local quit tears down the operator terminal instead of restarting it" do
    terminal_id = unique_terminal_id("ops-local-quit")

    on_exit(fn ->
      assert OperatorTerminal.stop(terminal_id) in [:ok, {:error, :not_found}]
      :ok
    end)

    assert {:ok, terminal} =
             OperatorTerminal.start_link(
               mod: App,
               app_opts: [label: "local-terminal", test_mode: {40, 10}],
               surface_kind: :local_terminal,
               surface_ref: terminal_id
             )

    ref = Process.monitor(terminal)
    backend_pid = :sys.get_state(terminal).backend_pid

    assert :ok =
             Runtime.inject_event(
               backend_pid,
               %Event.Key{code: "q", modifiers: ["ctrl"], kind: "press"}
             )

    assert_receive {:DOWN, ^ref, :process, ^terminal, :normal}

    refute Process.alive?(terminal)
    refute Process.alive?(backend_pid)
    assert OperatorTerminal.info(terminal_id) == nil
    refute Enum.any?(OperatorTerminal.list(), &(&1.terminal_id == terminal_id))

    case Registry.lookup(ExecutionPlane.OperatorTerminal.Registry, terminal_id) do
      [] ->
        :ok

      [{pid, _value}] ->
        refute Process.alive?(pid)
    end
  end

  test "start_link/1 hosts an SSH operator terminal through the generic ingress family" do
    parent = self()
    terminal_id = unique_terminal_id("ops-ssh")

    on_exit(fn ->
      assert OperatorTerminal.stop(terminal_id) in [:ok, {:error, :not_found}]
      :ok
    end)

    daemon_starter = fn port, daemon_opts ->
      send(parent, {:ssh_daemon_started, port, daemon_opts})
      {:ok, {:fake_daemon, port}}
    end

    daemon_stopper = fn ref ->
      send(parent, {:ssh_daemon_stopped, ref})
      :ok
    end

    assert {:ok, terminal} =
             OperatorTerminal.start_link(
               mod: App,
               app_opts: [label: "ssh-terminal"],
               surface_kind: :ssh_terminal,
               surface_ref: terminal_id,
               transport_options: [
                 port: 4022,
                 daemon_starter: daemon_starter,
                 daemon_stopper: daemon_stopper,
                 auth_methods: ~c"password",
                 user_passwords: [{~c"demo", ~c"demo"}]
               ]
             )

    assert_receive {:ssh_daemon_started, 4022, daemon_opts}
    assert daemon_opts[:auth_methods] == ~c"password"

    assert %OperatorTerminal.Info{} = info = OperatorTerminal.info(terminal_id)
    assert info.surface_kind == :ssh_terminal
    assert info.adapter_metadata[:port] == 4022
    assert info.transport_options[:port] == 4022
    assert info.transport_options[:auth_methods] == ~c"password"

    assert 4022 == OperatorTerminal.port(terminal)

    assert :ok = OperatorTerminal.stop(terminal)
    assert_receive {:ssh_daemon_stopped, {:fake_daemon, 4022}}
  end

  defp unique_terminal_id(prefix) do
    "#{prefix}-#{System.unique_integer([:positive])}"
  end
end
