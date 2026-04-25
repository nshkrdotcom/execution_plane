defmodule ExecutionPlane.Protocols.JsonRpc do
  @moduledoc """
  Minimal JSON-RPC framing support. Process-backed JSON-RPC is composed by a
  direct lower-lane owner that depends on both JSON-RPC and process lanes.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntent
  alias ExecutionPlane.Kernel.DispatchPlan

  @spec protocol() :: String.t()
  def protocol, do: "jsonrpc"

  @spec supports_intent?(struct() | map() | keyword()) :: boolean()
  def supports_intent?(%{__struct__: ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1}),
    do: true

  def supports_intent?(_other), do: false

  @spec execute(DispatchPlan.t(), keyword()) :: {:ok, map()}
  def execute(
        %DispatchPlan{
          intent: %{__struct__: ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1} = intent,
          route: route,
          timeout_ms: timeout_ms
        },
        _opts
      ) do
    request = build_request(intent)

    {:ok,
     %{
       family: "jsonrpc",
       raw_payload: %{
         request: request,
         target: Contracts.stringify_keys(route.resolved_target),
         timeout_ms: timeout_ms,
         process_backed: false
       },
       metrics: %{},
       failure: nil
     }}
  end

  defp build_request(%JsonRpcExecutionIntent{} = intent) do
    intent.request
    |> Contracts.stringify_keys()
    |> Map.put_new("jsonrpc", "2.0")
    |> Map.put_new("id", intent.envelope.attempt_ref)
  end
end
