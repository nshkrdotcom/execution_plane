defmodule ExecutionPlane.JsonRpc do
  @moduledoc """
  Helper surface for JSON-RPC framing and direct owner composition.

  This helper emits `JsonRpcExecutionIntent.v1`, resolves the local process
  target used for the request/response exchange, and executes through the
  kernel.
  """

  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntent
  alias ExecutionPlane.ExecutionEvent
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Kernel
  alias ExecutionPlane.Kernel.ExecutionResult, as: KernelExecutionResult
  alias ExecutionPlane.Lane.Capabilities
  alias ExecutionPlane.LaneSupport
  alias ExecutionPlane.Protocols.JsonRpc.Adapter

  @behaviour ExecutionPlane.Lane.Adapter

  @impl true
  def lane_id, do: :jsonrpc

  @impl true
  def capabilities do
    Capabilities.new!(
      lane_id: "jsonrpc",
      protocols: ["jsonrpc"],
      surfaces: ["framing"],
      supports_execute: true,
      supports_stream: true,
      metadata: %{"process_backed" => false}
    )
  end

  @impl true
  def validate(%ExecutionRequest{lane_id: "jsonrpc"}), do: :ok

  def validate(_request) do
    {:error,
     Rejection.new(
       :invalid_lane_request,
       "JSON-RPC adapter only accepts lane_id=jsonrpc"
     )}
  end

  @impl true
  def execute(%ExecutionRequest{} = request, _opts) do
    {:ok,
     ExecutionResult.new!(
       execution_ref: request.execution_ref,
       status: "succeeded",
       output: %{
         "framed_request" => Adapter.encode_once(request.payload)
       },
       provenance: request.provenance
     )}
  end

  @impl true
  def stream(%ExecutionRequest{} = request, _opts) do
    event =
      ExecutionEvent.new!(
        execution_ref: request.execution_ref,
        event_type: "jsonrpc.framed",
        payload: %{
          "framed_request" => Adapter.encode_once(request.payload)
        }
      )

    {:ok, [event]}
  end

  @spec call(map() | keyword(), keyword()) ::
          {:ok, KernelExecutionResult.t()} | {:error, KernelExecutionResult.t()}
  def call(binding, opts \\ []) do
    binding = Contracts.normalize_attrs(binding)
    timeout_ms = timeout_ms(binding)
    lineage = LaneSupport.build_lineage("process", Keyword.get(opts, :lineage, %{}))

    intent =
      JsonRpcExecutionIntent.new!(%{
        envelope:
          LaneSupport.build_envelope(
            "process",
            "jsonrpc",
            "jsonrpc.unary",
            lineage,
            Keyword.get(opts, :envelope, %{})
          ),
        transport_binding:
          Contracts.fetch_optional_map!(binding, :transport_binding, %{"mode" => "stdio"}),
        protocol_schema:
          Contracts.fetch_optional_map!(binding, :protocol_schema, %{"schema" => "jsonrpc-2.0"}),
        request: Contracts.fetch_optional_map!(binding, :request, %{}),
        session_policy: Contracts.fetch_optional_map!(binding, :session_policy, %{})
      })

    route =
      LaneSupport.build_route(
        "process",
        "jsonrpc",
        "process",
        "local",
        %{
          "command" => Contracts.fetch_required_stringish!(binding, :command),
          "argv" => Contracts.fetch_optional_list!(binding, :argv, [], &to_string/1),
          "cwd" => Contracts.fetch_optional_stringish!(binding, :cwd),
          "env" => Contracts.fetch_optional_map!(binding, :env, %{}),
          "execution_surface" => execution_surface(binding)
        },
        timeout_ms,
        lineage,
        Keyword.get(opts, :route, %{})
      )

    Kernel.execute(intent, route, LaneSupport.kernel_opts(opts))
  end

  defp timeout_ms(binding) do
    case Contracts.fetch_value(binding, :timeout_ms) do
      timeout when is_integer(timeout) and timeout > 0 -> timeout
      _other -> nil
    end
  end

  defp execution_surface(binding) do
    case Contracts.fetch_value(binding, :execution_surface) do
      nil ->
        %{
          "surface_kind" =>
            Contracts.fetch_optional_stringish!(binding, :surface_kind, "local_subprocess")
        }

      surface ->
        Contracts.ensure_map!(surface, "execution_surface")
    end
  end
end
