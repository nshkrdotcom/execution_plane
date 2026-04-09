defmodule ExecutionPlane.Protocols.JsonRpc do
  @moduledoc """
  Minimal unary JSON-RPC support over the process runtime.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.Failure
  alias ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntent
  alias ExecutionPlane.Kernel.DispatchPlan
  alias ExecutionPlane.Runtimes.Process

  @spec protocol() :: String.t()
  def protocol, do: "jsonrpc"

  @spec supports_intent?(struct() | map() | keyword()) :: boolean()
  def supports_intent?(%{__struct__: ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1}),
    do: true

  def supports_intent?(_other), do: false

  @spec execute(DispatchPlan.t(), keyword()) :: {:ok, map()} | {:error, map()}
  def execute(
        %DispatchPlan{
          intent: %{__struct__: ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1} = intent,
          route: route,
          timeout_ms: timeout_ms
        },
        _opts
      ) do
    request = build_request(intent)
    target = route.resolved_target

    case Process.run(
           command: Contracts.fetch_value(target, :command),
           argv: Contracts.fetch_value(target, :argv) || [],
           cwd: Contracts.fetch_value(target, :cwd),
           env: Contracts.fetch_value(target, :env) || %{},
           stdin: Jason.encode!(request) <> "\n",
           timeout: timeout_ms,
           surface_kind:
             target
             |> Contracts.fetch_value(:execution_surface)
             |> case do
               nil -> "local_subprocess"
               surface -> Contracts.fetch_value(surface, :surface_kind) || "local_subprocess"
             end
         ) do
      {:ok, result} ->
        raw_payload = %{
          request: request,
          stdout: result.stdout,
          stderr: result.stderr,
          exit: ExecutionPlane.Runtimes.Process.Exit.to_map(result.exit)
        }

        with {:ok, response} <- Jason.decode(result.stdout),
             true <- response["id"] == request["id"] do
          if response["error"] do
            {:error,
             %{
               family: "process",
               raw_payload: Map.put(raw_payload, :response, response),
               metrics: %{},
               failure:
                 Failure.new!(%{
                   failure_class: :semantic_runtime_failed,
                   reason: "jsonrpc response returned an error"
                 })
             }}
          else
            {:ok,
             %{
               family: "process",
               raw_payload: Map.put(raw_payload, :response, response),
               metrics: %{},
               failure: nil
             }}
          end
        else
          _other ->
            {:error,
             %{
               family: "process",
               raw_payload: raw_payload,
               metrics: %{},
               failure:
                 Failure.new!(%{
                   failure_class: :protocol_framing_failed,
                   reason: "invalid jsonrpc response"
                 })
             }}
        end

      {:error, {:timeout, context}} ->
        {:error,
         %{
           family: "process",
           raw_payload: context,
           metrics: %{},
           failure:
             Failure.new!(%{failure_class: :timeout, reason: "jsonrpc execution timed out"})
         }}

      {:error, {:command_not_found, command}} ->
        {:error,
         %{
           family: "process",
           raw_payload: %{command: command},
           metrics: %{},
           failure:
             Failure.new!(%{failure_class: :launch_failed, reason: "jsonrpc command not found"})
         }}

      {:error, reason} ->
        {:error,
         %{
           family: "process",
           raw_payload: %{error: inspect(reason)},
           metrics: %{},
           failure:
             Failure.new!(%{
               failure_class: :transport_failed,
               reason: "jsonrpc transport execution failed"
             })
         }}
    end
  end

  defp build_request(%JsonRpcExecutionIntent{} = intent) do
    intent.request
    |> Contracts.stringify_keys()
    |> Map.put_new("jsonrpc", "2.0")
    |> Map.put_new("id", intent.envelope.attempt_ref)
  end
end
