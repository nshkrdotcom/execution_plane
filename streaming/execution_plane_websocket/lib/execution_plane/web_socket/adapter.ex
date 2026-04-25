defmodule ExecutionPlane.WebSocket.Adapter do
  @moduledoc false

  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.ExecutionEvent
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Lane.Capabilities

  @behaviour ExecutionPlane.Lane.Adapter

  @impl true
  def lane_id, do: :websocket

  @impl true
  def capabilities do
    Capabilities.new!(
      lane_id: "websocket",
      protocols: ["websocket"],
      surfaces: ["ws", "wss"],
      supports_execute: false,
      supports_stream: true
    )
  end

  @impl true
  def validate(%ExecutionRequest{lane_id: "websocket"}), do: :ok

  def validate(_request) do
    {:error,
     Rejection.new(:invalid_lane_request, "WebSocket adapter only accepts lane_id=websocket")}
  end

  @impl true
  def execute(%ExecutionRequest{} = request, _opts) do
    {:error,
     ExecutionResult.new!(
       execution_ref: request.execution_ref,
       status: "failed",
       error: "WebSocket is a streaming lane",
       provenance: request.provenance
     )}
  end

  @impl true
  def stream(%ExecutionRequest{} = request, _opts) do
    {:ok,
     [
       ExecutionEvent.new!(
         execution_ref: request.execution_ref,
         event_type: "websocket.stream.requested",
         payload: request.payload
       )
     ]}
  end
end
