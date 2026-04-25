defmodule ExecutionPlane.ProcessTransportLowerSimulationTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Command
  alias ExecutionPlane.Process.Transport
  alias ExecutionPlane.Process.Transport.{Info, RunResult}
  alias ExecutionPlane.ProcessExit

  test "run/2 replays configured output without spawning a process" do
    command = Command.new("execution-plane-command-must-not-exist", ["--ignored"])

    assert {:ok, %RunResult{} = result} =
             Transport.run(command,
               execution_surface: [
                 surface_kind: :lower_simulation,
                 transport_options: [
                   scenario_ref: "lower-simulation://process/run",
                   stdout: "wire-ok\n",
                   stderr: "wire-warning\n",
                   exit_code: 0
                 ]
               ]
             )

    assert result.invocation.command == "execution-plane-command-must-not-exist"
    assert result.stdout == "wire-ok\n"
    assert result.stderr == "wire-warning\n"
    assert result.output == "wire-ok\n"
    assert %ProcessExit{status: :success, code: 0} = result.exit
  end

  test "start/1 replays provider-native frames through tagged transport delivery" do
    ref = make_ref()

    assert {:ok, transport} =
             Transport.start(
               command: Command.new("missing-provider-cli"),
               subscriber: {self(), ref},
               event_tag: :lower_sim_transport,
               execution_surface: [
                 surface_kind: :lower_simulation,
                 target_id: "simulated-cli",
                 transport_options: [
                   scenario_ref: "lower-simulation://process/session",
                   stdout_frames: ["{\"type\":\"message\",\"delta\":\"hello\"}\n"],
                   stderr_frames: ["diagnostic\n"],
                   exit: :normal
                 ],
                 observability: %{trace_id: "trace-prelim"}
               ]
             )

    assert Transport.status(transport) == :connected

    assert_receive {:lower_sim_transport, ^ref,
                    {:message, "{\"type\":\"message\",\"delta\":\"hello\"}\n"}},
                   1_000

    assert_receive {:lower_sim_transport, ^ref, {:stderr, "diagnostic\n"}}, 1_000
    assert_receive {:lower_sim_transport, ^ref, {:exit, %ProcessExit{status: :success}}}, 1_000

    assert %Info{} = info = Transport.info(transport)
    assert info.surface_kind == :lower_simulation
    assert info.adapter_metadata.lower_simulation?
    assert info.adapter_metadata.scenario_ref == "lower-simulation://process/session"
    assert info.adapter_metadata.side_effect_policy == "deny_process_spawn"
    assert info.observability == %{trace_id: "trace-prelim"}

    assert :ok = Transport.close(transport)
  end

  test "missing scenario_ref fails before command spawn" do
    command = Command.new("execution-plane-command-must-not-exist")

    assert {:error, {:transport, error}} =
             Transport.run(command,
               execution_surface: [
                 surface_kind: :lower_simulation,
                 transport_options: [stdout: "ignored"]
               ]
             )

    assert error.reason ==
             {:invalid_transport_options, {:missing_required_option, :scenario_ref, nil}}
  end
end
