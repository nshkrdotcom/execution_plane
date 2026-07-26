defmodule ExecutionPlane.RuntimeContractsTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.{ActiveExecution, ExecutionRef}
  alias ExecutionPlane.Family.{HTTPRequest, ProcessRequest, WebSocketRequest}
  alias ExecutionPlane.Runtime.{Client, Event, Lifecycle, Status}

  defp active do
    ActiveExecution.new!(
      execution_ref: "execution://nshkr/run-1",
      session_ref: "session://asm/run-1/generation-1",
      admission_decision_ref: "admission://execution-plane/run-1",
      node_id: "node://execution-plane/local",
      lane_id: "process.codex.local",
      state: "accepted",
      started_at: ~U[2026-07-15 12:00:00Z],
      fence: 7
    )
  end

  test "Runtime Client freezes the six interactive lifecycle callbacks" do
    callbacks = Client.behaviour_info(:callbacks) |> MapSet.new()

    assert callbacks ==
             MapSet.new([
               {:start, 2},
               {:subscribe, 3},
               {:send_input, 3},
               {:end_input, 2},
               {:status, 2},
               {:cancel, 2}
             ])
  end

  test "active execution requires an opaque session and terminal receipt" do
    value = active()
    assert %ExecutionRef{} = value.execution_ref
    refute ActiveExecution.terminal?(value)

    assert {:error, :invalid_active_execution} =
             value |> Map.from_struct() |> Map.put(:state, "completed") |> ActiveExecution.new()

    assert {:ok, terminal} =
             value
             |> Map.from_struct()
             |> Map.merge(%{state: "completed", receipt_ref: "receipt://execution-plane/run-1"})
             |> ActiveExecution.new()

    assert ActiveExecution.terminal?(terminal)
  end

  test "lifecycle rejects success after cancellation and requires terminal receipt" do
    assert {:ok, running} = Lifecycle.transition(active(), :running)

    assert {:ok, cancelled} =
             Lifecycle.transition(running, :cancelled, "receipt://execution-plane/run-1/cancel")

    assert {:error, :invalid_execution_transition} =
             Lifecycle.transition(
               cancelled,
               :completed,
               "receipt://execution-plane/run-1/success"
             )
  end

  test "terminal status closes both directions and exposes a receipt" do
    assert {:ok, status} =
             Status.new(
               execution_ref: "execution://nshkr/run-1",
               state: "cancelled",
               sequence: 4,
               input_open: false,
               output_open: false,
               receipt_ref: "receipt://execution-plane/run-1/cancel"
             )

    assert Status.terminal?(status)

    assert {:error, :invalid_runtime_status} =
             Status.new(
               execution_ref: "execution://nshkr/run-1",
               state: "cancelled",
               sequence: 4,
               input_open: true,
               output_open: false,
               receipt_ref: "receipt://execution-plane/run-1/cancel"
             )
  end

  test "runtime events reject secret-bearing payloads" do
    assert {:ok, event} =
             Event.new(
               execution_ref: "execution://nshkr/run-1",
               sequence: 1,
               kind: :output,
               emitted_at: ~U[2026-07-15 12:00:01Z],
               payload: %{"chunk" => "hello"}
             )

    assert event.kind == "output"

    assert {:error, {:raw_credential_key_forbidden, "api_key"}} =
             Event.new(
               execution_ref: "execution://nshkr/run-1",
               sequence: 2,
               kind: :output,
               emitted_at: ~U[2026-07-15 12:00:02Z],
               payload: %{"api_key" => "sentinel-secret"}
             )

    assert {:error, :invalid_runtime_event} =
             Event.new(
               execution_ref: "execution://nshkr/run-1",
               sequence: 2,
               kind: :output,
               emitted_at: ~U[2026-07-15 12:00:02Z],
               payload: %{"chunk" => "hello"},
               token: "sentinel-secret"
             )
  end

  test "process, HTTP, and WebSocket requests retain distinct lifecycles" do
    assert {:ok, process} =
             ProcessRequest.new(
               command_ref: "command://codex/run-1",
               executable: "codex",
               arguments: ["app-server"],
               working_directory_ref: "workspace://synapse/run-1",
               environment_materialization_ref: "materialization://jido/run-1",
               stdin_mode: :pipe,
               deadline_at: ~U[2026-07-15 12:05:00Z]
             )

    assert process.stdin_mode == "pipe"

    assert {:ok, http} =
             HTTPRequest.new(
               request_ref: "request://gemini/run-1",
               endpoint_ref: "endpoint://google/gemini-api",
               method: :post,
               path: "/v1/models/gemini-2.5-flash:streamGenerateContent",
               header_policy_ref: "header-policy://jido/gemini",
               response_mode: :incremental,
               idempotency_key: "gemini:run-1:attempt-1",
               deadline_at: ~U[2026-07-15 12:05:00Z],
               body_artifact_ref: "artifact://outer-brain/prompt-1"
             )

    assert http.response_mode == "incremental"

    assert {:ok, websocket} =
             WebSocketRequest.new(
               connection_ref: "connection://gemini-live/run-1",
               endpoint_ref: "endpoint://google/gemini-live",
               subprotocols: ["gemini-live-v1"],
               materialization_ref: "materialization://jido/live/run-1",
               backpressure_limit: 32,
               deadline_at: ~U[2026-07-15 12:05:00Z]
             )

    assert websocket.backpressure_limit == 32
  end
end
