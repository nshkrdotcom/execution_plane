defmodule ExecutionPlane.Process.Transport.GuestBridgeStateMachineTest.FakeBridge do
  @moduledoc false

  use GenServer

  alias ExecutionPlane.Process.Transport.GuestBridge
  alias ExecutionPlane.Process.Transport.GuestBridge.Protocol

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl GenServer
  def init(_opts), do: {:ok, %{active: nil, recv_queue: :queue.new()}}

  @impl GenServer
  def handle_call(
        {:send_frame, %{"kind" => "request", "id" => id, "op" => op} = frame},
        _from,
        state
      ) do
    {:reply, :ok, handle_request(op, id, frame, state)}
  end

  def handle_call({:activate, owner}, _from, state) when is_pid(owner) do
    {:reply, :ok, %{state | active: owner}}
  end

  def handle_call({:recv_chunk, _timeout_ms}, _from, state) do
    case :queue.out(state.recv_queue) do
      {{:value, chunk}, recv_queue} -> {:reply, {:ok, chunk}, %{state | recv_queue: recv_queue}}
      {:empty, recv_queue} -> {:reply, {:error, :empty}, %{state | recv_queue: recv_queue}}
    end
  end

  def handle_call(:close, _from, state), do: {:reply, :ok, state}

  defp handle_request("attach", id, _frame, state) do
    payload = %{
      "bridge_session_ref" => "bridge-session://test",
      "bridge_profile" => "core_cli_transport",
      "protocol_version" => Protocol.version(),
      "effective_capabilities" => Protocol.capabilities_to_external(GuestBridge.capabilities()),
      "extensions" => %{}
    }

    enqueue_recv(state, Protocol.response(id, true, payload))
  end

  defp handle_request("start_session", id, _frame, state) do
    enqueue_recv(state, Protocol.response(id, true, %{}))
  end

  defp handle_request("stdin", id, frame, state) do
    data =
      frame
      |> get_in(["payload", "data"])
      |> Protocol.decode_bytes()
      |> case do
        {:ok, decoded} -> decoded
        :error -> ""
      end

    send_active(state, [
      Protocol.response(id, true, %{}),
      Protocol.event("stdout", %{"data" => Protocol.encode_bytes("guest:#{String.trim(data)}\n")})
    ])
  end

  defp handle_request("stdin_eof", id, _frame, state) do
    send_active(state, [
      Protocol.response(id, true, %{}),
      Protocol.event("exit", %{"status" => "success", "code" => 0, "stderr" => ""})
    ])
  end

  defp handle_request("close", _id, _frame, state), do: state

  defp handle_request(op, id, _frame, state) do
    send_active(state, [
      Protocol.response(id, false, %{}, %{"code" => "unknown_op", "details" => %{"op" => op}})
    ])
  end

  defp enqueue_recv(state, frame) do
    %{state | recv_queue: :queue.in(Protocol.encode_frame(frame), state.recv_queue)}
  end

  defp send_active(%{active: owner} = state, frames) when is_pid(owner) do
    data = frames |> Enum.map(&Protocol.encode_frame/1) |> IO.iodata_to_binary()
    send(owner, {:bridge_data, self(), data})
    state
  end

  defp send_active(state, _frames), do: state
end

defmodule ExecutionPlane.Process.Transport.GuestBridgeStateMachineTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Process.Transport.GuestBridge
  alias ExecutionPlane.Process.Transport.GuestBridge.Protocol
  alias ExecutionPlane.Process.Transport.GuestBridgeStateMachineTest.FakeBridge
  alias ExecutionPlane.ProcessExit

  @event_tag :guest_bridge_state_machine

  test "guest bridge session streams stdin, stdout, eof, and exit through request tracking" do
    bridge = start_supervised!({FakeBridge, []})
    ref = make_ref()

    assert {:ok, transport} =
             GuestBridge.start(
               command: "ignored",
               surface_kind: :guest_bridge,
               transport_options: transport_options(),
               adapter_metadata: %{test_connection: bridge},
               subscriber: {self(), ref},
               event_tag: @event_tag
             )

    assert GuestBridge.status(transport) == :connected
    assert :ok = GuestBridge.send(transport, "hello")
    assert_receive {@event_tag, ^ref, {:message, "guest:hello"}}, 1_000

    assert :ok = GuestBridge.end_input(transport)

    assert_receive {
                     @event_tag,
                     ^ref,
                     {:exit, %ProcessExit{status: :success, code: 0, stderr: ""}}
                   },
                   1_000

    assert :ok = GuestBridge.close(transport)
  end

  test "protocol atom-ish decoding is bounded for platform status values" do
    assert {:ok, :success} = Protocol.decode_atomish("success", [:success, :exit, :error])

    assert {:error, {:invalid_atomish_value, "provider_success", [:success]}} =
             Protocol.decode_atomish("provider_success", [:success])

    assert {:error, _reason} =
             Protocol.capabilities_from_external(%{"startup_kind" => "provider_spawn"})
  end

  defp transport_options do
    [
      endpoint: %{kind: :tcp, host: "127.0.0.1", port: 1},
      bridge_ref: "bridge://test",
      bridge_profile: "core_cli_transport",
      supported_protocol_versions: [Protocol.version()],
      extensions: %{},
      connect_timeout_ms: 1_000,
      request_timeout_ms: 1_000
    ]
  end
end
