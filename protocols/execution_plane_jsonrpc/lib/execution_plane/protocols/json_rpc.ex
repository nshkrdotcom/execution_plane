defmodule ExecutionPlane.Protocols.JsonRpc do
  @moduledoc """
  Minimal unary JSON-RPC support over the process runtime.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.Failure
  alias ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntent
  alias ExecutionPlane.Kernel.DispatchPlan
  alias ExecutionPlane.Runtimes.Process
  alias ExecutionPlane.Runtimes.Process.Exit

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

    route.resolved_target
    |> run_jsonrpc_process(request, timeout_ms)
    |> jsonrpc_execution_result(request)
  end

  defp run_jsonrpc_process(target, request, timeout_ms) do
    Process.run(
      command: Contracts.fetch_value(target, :command),
      argv: Contracts.fetch_value(target, :argv) || [],
      cwd: Contracts.fetch_value(target, :cwd),
      env: Contracts.fetch_value(target, :env) || %{},
      stdin: Jason.encode!(request) <> "\n",
      timeout: timeout_ms,
      surface_kind: target |> Contracts.fetch_value(:execution_surface) |> surface_kind()
    )
  end

  defp jsonrpc_execution_result({:ok, result}, request) do
    raw_payload = %{
      request: request,
      stdout: result.stdout,
      stderr: result.stderr,
      exit: Exit.to_map(result.exit)
    }

    result.stdout
    |> decode_matching_response(request)
    |> response_result(raw_payload)
  end

  defp jsonrpc_execution_result({:error, {:timeout, context}}, _request) do
    error_result(context, :timeout, "jsonrpc execution timed out")
  end

  defp jsonrpc_execution_result({:error, {:command_not_found, command}}, _request) do
    error_result(%{command: command}, :launch_failed, "jsonrpc command not found")
  end

  defp jsonrpc_execution_result({:error, reason}, _request) do
    error_result(
      %{error: inspect(reason)},
      :transport_failed,
      "jsonrpc transport execution failed"
    )
  end

  defp decode_matching_response(stdout, request) do
    with {:ok, response} <- Jason.decode(stdout),
         true <- response["id"] == request["id"] do
      {:ok, response}
    else
      _other -> :error
    end
  end

  defp response_result({:ok, %{"error" => error} = response}, raw_payload)
       when not is_nil(error) do
    raw_payload
    |> Map.put(:response, response)
    |> error_result(:semantic_runtime_failed, "jsonrpc response returned an error")
  end

  defp response_result({:ok, response}, raw_payload) do
    {:ok,
     %{
       family: "process",
       raw_payload: Map.put(raw_payload, :response, response),
       metrics: %{},
       failure: nil
     }}
  end

  defp response_result(:error, raw_payload) do
    error_result(raw_payload, :protocol_framing_failed, "invalid jsonrpc response")
  end

  defp error_result(raw_payload, failure_class, reason) do
    {:error,
     %{
       family: "process",
       raw_payload: raw_payload,
       metrics: %{},
       failure: Failure.new!(%{failure_class: failure_class, reason: reason})
     }}
  end

  defp surface_kind(nil), do: "local_subprocess"

  defp surface_kind(surface),
    do: Contracts.fetch_value(surface, :surface_kind) || "local_subprocess"

  defp build_request(%JsonRpcExecutionIntent{} = intent) do
    intent.request
    |> Contracts.stringify_keys()
    |> Map.put_new("jsonrpc", "2.0")
    |> Map.put_new("id", intent.envelope.attempt_ref)
  end
end
