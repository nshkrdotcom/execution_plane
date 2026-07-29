defmodule ExecutionPlane.Process.ActiveAdapterTest do
  use ExUnit.Case, async: false

  alias Elixir.Process, as: BEAMProcess
  alias ExecutionPlane.Admission.Request
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.Family.ProcessRequest
  alias ExecutionPlane.Process
  alias ExecutionPlane.Process.RuntimeClientGateway
  alias ExecutionPlane.Process.Transport

  test "interactive process accepts input, EOF, ordered output, and a terminal result" do
    execution_request = execution_request("/bin/cat", [], "pipe")

    assert {:ok, handle} =
             Process.active_start(execution_request, self(),
               working_directories: %{"workspace://tmp" => "/tmp"},
               environment_materializations: %{"environment://empty" => %{}}
             )

    assert :ok = Process.active_send_input(handle, "alpha\n", [])

    assert {:ok, {:output, output}} = receive_active_event(handle)
    assert output == %{"family" => "process", "stream" => "stdout", "data" => "alpha"}

    assert :ok = Process.active_end_input(handle, [])

    assert {:ok, {:terminal, "completed", result}} = receive_active_event(handle)
    assert result.status == "succeeded"
    assert result.output["process_exit"]["code"] == 0
  end

  test "cancel interrupts and force-closes the lower process lifecycle" do
    execution_request = execution_request("/bin/sleep", ["30"], "none")

    assert {:ok, handle} =
             Process.active_start(execution_request, self(),
               working_directories: %{"workspace://tmp" => "/tmp"},
               environment_materializations: %{"environment://empty" => %{}}
             )

    assert Transport.status(handle.transport) == :connected
    assert :ok = Process.active_cancel(handle, "test_cancel", [])
    assert_eventually_disconnected(handle.transport)
  end

  test "unknown materialization refs fail closed before spawn" do
    assert {:error, {:unknown_process_materialization, :working_directory, "workspace://tmp"}} =
             Process.active_start(execution_request("/bin/true", [], "none"), self(),
               working_directories: %{},
               environment_materializations: %{"environment://empty" => %{}}
             )
  end

  defp execution_request(executable, arguments, stdin_mode) do
    family_request =
      ProcessRequest.new(%{
        command_ref: "command://test/process",
        executable: executable,
        arguments: arguments,
        working_directory_ref: "workspace://tmp",
        environment_materialization_ref: "environment://empty",
        stdin_mode: stdin_mode,
        deadline_at: DateTime.add(DateTime.utc_now(), 60, :second)
      })
      |> elem(1)

    admission =
      Request.new!(
        lane_id: "process",
        operation: "process.start",
        payload: %{
          "family" => "process",
          "family_contract" => "execution-plane.runtime-families.v1",
          "request" => RuntimeClientGateway.encode_request(family_request)
        },
        provenance: ExecutionPlane.Provenance.direct_lower_lane_owner("active-adapter-test")
      )

    ExecutionRequest.new!(
      execution_ref: ExecutionPlane.ExecutionRef.new!().ref,
      admission_request: admission,
      lane_id: "process",
      operation: "process.start",
      payload: admission.payload,
      provenance: admission.provenance
    )
  end

  defp receive_active_event(handle) do
    receive do
      message ->
        case Process.active_event(handle, message, []) do
          :ignore -> receive_active_event(handle)
          event -> event
        end
    after
      2_000 -> flunk("timed out waiting for process active event")
    end
  end

  defp assert_eventually_disconnected(transport, attempts \\ 40)
  defp assert_eventually_disconnected(_transport, 0), do: flunk("process remained connected")

  defp assert_eventually_disconnected(transport, attempts) do
    if Transport.status(transport) == :disconnected do
      :ok
    else
      BEAMProcess.sleep(25)
      assert_eventually_disconnected(transport, attempts - 1)
    end
  end
end
