defmodule ExecutionPlane.NodeActiveRuntimeTest.ActiveLane do
  @moduledoc false

  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Lane.Capabilities

  def lane_id, do: :process

  def capabilities do
    Capabilities.new!(
      lane_id: "process",
      protocols: ["process"],
      surfaces: ["test"],
      supports_execute: true,
      supports_stream: true
    )
  end

  def validate(%{lane_id: "process"}), do: :ok

  def execute(_request, _opts),
    do: raise("active admission must not synchronously enter execute/2")

  def stream(_request, _opts),
    do: raise("active admission must not synchronously enter stream/2")

  def active_start(request, owner, opts) do
    if delay = Keyword.get(opts, :start_delay_ms), do: Process.sleep(delay)
    probe = Keyword.fetch!(opts, :probe)
    pid = spawn(fn -> loop(request, owner, probe) end)
    send(probe, {:lower_started, request.execution_ref, pid})
    if burst = Keyword.get(opts, :burst), do: send(pid, {:burst, burst})
    {:ok, pid}
  end

  def active_send_input(handle, input, _opts) do
    send(handle, {:input, IO.iodata_to_binary(input)})
    :ok
  end

  def active_end_input(handle, _opts) do
    send(handle, :end_input)
    :ok
  end

  def active_cancel(handle, reason, _opts) do
    send(handle, {:cancel, reason})
    :ok
  end

  def active_event(_handle, _message, _opts), do: :ignore

  defp loop(request, owner, probe) do
    receive do
      {:input, input} ->
        send(owner, {:execution_plane_active, {:output, %{"data" => input}}})
        loop(request, owner, probe)

      {:burst, count} ->
        Enum.each(1..count, fn index ->
          send(owner, {:execution_plane_active, {:output, %{"index" => index}}})
        end)

        loop(request, owner, probe)

      :end_input ->
        result =
          ExecutionResult.new!(
            execution_ref: request.execution_ref,
            status: "succeeded",
            output: %{"eof" => true},
            provenance: request.provenance
          )

        send(owner, {:execution_plane_active, {:terminal, "completed", result}})

      {:cancel, reason} ->
        send(probe, {:lower_cancelled, request.execution_ref, reason})
    end
  end
end

defmodule ExecutionPlane.NodeActiveRuntimeTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Admission.Request
  alias ExecutionPlane.Node.{DistributedClient, ExecutionRegistry, ExecutionSupervisor, Server}
  alias ExecutionPlane.NodeActiveRuntimeTest.ActiveLane
  alias ExecutionPlane.Runtime.Event

  setup do
    suffix = System.unique_integer([:positive])
    registry = :"active_registry_#{suffix}"
    supervisor = :"active_supervisor_#{suffix}"
    server = :"active_server_#{suffix}"

    start_supervised!({ExecutionRegistry, name: registry})
    start_supervised!({ExecutionSupervisor, name: supervisor})

    start_supervised!(
      {Server,
       name: server,
       node_id: "active-node",
       execution_registry: registry,
       execution_supervisor: supervisor,
       execution_cleanup_after_ms: 100}
    )

    :ok =
      Server.register_lane(server, ActiveLane, active_options: [probe: self()])

    %{registry: registry, server: server, supervisor: supervisor}
  end

  test "admission returns promptly and lifecycle stays behind an opaque ref", %{server: server} do
    :ok =
      Server.register_lane(server, ActiveLane,
        active_options: [probe: self(), start_delay_ms: 200]
      )

    started_at = System.monotonic_time(:millisecond)
    assert {:ok, active} = DistributedClient.start(request(), server: server)
    elapsed = System.monotonic_time(:millisecond) - started_at

    assert elapsed < 150
    assert active.node_id == "active-node"
    assert active.lane_id == "process"
    assert active.state == "accepted"
    refute is_pid(active.execution_ref)

    assert :ok =
             DistributedClient.subscribe(active.execution_ref, self(),
               server: server,
               fence: active.fence
             )

    assert_receive {:lower_started, ref, lower_pid}, 500
    assert ref == active.execution_ref.ref
    assert is_pid(lower_pid)
    assert_receive {:execution_plane_runtime, ^ref, %Event{kind: "started", sequence: 1}}, 500

    assert :ok =
             DistributedClient.send_input(active.execution_ref, "alpha",
               server: server,
               fence: active.fence
             )

    assert_receive {:execution_plane_runtime, ^ref,
                    %Event{kind: "output", sequence: 2, payload: %{"data" => "alpha"}}}

    assert {:error, :stale_execution_fence} =
             DistributedClient.send_input(active.execution_ref, "stale",
               server: server,
               fence: active.fence + 1
             )

    assert :ok =
             DistributedClient.end_input(active.execution_ref,
               server: server,
               fence: active.fence
             )

    assert_receive {:execution_plane_runtime, ^ref, %Event{kind: "input_closed", sequence: 3}}

    assert_receive {:execution_plane_runtime, ^ref,
                    %Event{
                      kind: "receipt",
                      sequence: 4,
                      payload: %{
                        "receipt_ref" => receipt_ref,
                        "terminal_state" => "completed"
                      }
                    }}

    assert String.starts_with?(receipt_ref, "receipt://execution-plane/")

    assert {:ok, status} =
             DistributedClient.status(active.execution_ref,
               server: server,
               fence: active.fence
             )

    assert status.state == "completed"
    assert status.input_open == false
    assert status.output_open == false
    assert status.receipt_ref == receipt_ref

    Process.sleep(150)

    assert {:error, :unknown_execution_ref} =
             DistributedClient.status(active.execution_ref, server: server)
  end

  test "cancel reaches the lower lifecycle and yields an idempotent terminal receipt", %{
    server: server
  } do
    assert {:ok, active} = DistributedClient.start(request(), server: server)
    assert_receive {:lower_started, ref, _lower_pid}

    assert :ok = DistributedClient.subscribe(active.execution_ref, self(), server: server)
    assert_receive {:execution_plane_runtime, ^ref, %Event{kind: "started"}}

    assert :ok =
             DistributedClient.cancel(active.execution_ref,
               server: server,
               fence: active.fence,
               reason: "operator_cancel"
             )

    assert_receive {:lower_cancelled, ^ref, "operator_cancel"}

    assert_receive {:execution_plane_runtime, ^ref,
                    %Event{
                      kind: "receipt",
                      payload: %{"terminal_state" => "cancelled"}
                    }}

    assert :ok =
             DistributedClient.cancel(active.execution_ref,
               server: server,
               fence: active.fence
             )
  end

  test "distributed target is trusted configuration and never atomized from input" do
    assert {:error, :invalid_runtime_server} =
             DistributedClient.status("exec-1", server: "server@untrusted")

    assert {:error, :invalid_runtime_server} =
             DistributedClient.status("exec-1", server: {"server", "node@untrusted"})
  end

  test "bounded replay applies backpressure and cancels an overflowing lower lifecycle", %{
    registry: registry,
    supervisor: supervisor
  } do
    suffix = System.unique_integer([:positive])
    server = :"bounded_active_server_#{suffix}"

    start_supervised!(
      Supervisor.child_spec(
        {Server,
         name: server,
         node_id: "bounded-node",
         execution_registry: registry,
         execution_supervisor: supervisor,
         execution_event_limit: 3},
        id: server
      )
    )

    :ok =
      Server.register_lane(server, ActiveLane, active_options: [probe: self(), burst: 10])

    assert {:ok, active} = DistributedClient.start(request(), server: server)
    assert_receive {:lower_started, ref, _lower_pid}
    assert :ok = DistributedClient.subscribe(active.execution_ref, self(), server: server)

    events = collect_until_receipt(ref)
    assert Enum.any?(events, &match?(%Event{kind: "backpressure"}, &1))
    assert %Event{payload: %{"terminal_state" => "failed"}} = List.last(events)
    assert_receive {:lower_cancelled, ^ref, "event_buffer_overflow"}
  end

  defp request do
    Request.new!(
      lane_id: "process",
      operation: "process.start",
      payload: %{"family" => "process", "request" => %{"stdin_mode" => "pipe"}},
      provenance: ExecutionPlane.Provenance.direct_lower_lane_owner("runtime-test")
    )
  end

  defp collect_until_receipt(ref, acc \\ []) do
    receive do
      {:execution_plane_runtime, ^ref, %Event{kind: "receipt"} = event} ->
        Enum.reverse([event | acc])

      {:execution_plane_runtime, ^ref, %Event{} = event} ->
        collect_until_receipt(ref, [event | acc])
    after
      1_000 -> flunk("timed out waiting for terminal receipt")
    end
  end
end
