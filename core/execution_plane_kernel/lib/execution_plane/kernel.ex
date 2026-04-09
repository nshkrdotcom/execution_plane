defmodule ExecutionPlane.Kernel do
  @moduledoc """
  Minimal Wave 1 kernel shell.

  The kernel currently validates the frozen route and intent packet shape and
  resolves the lower protocol module. Durable truth, replay, and policy meaning
  remain outside this repo by design.
  """

  alias ExecutionPlane.Contracts.ExecutionRoute.V1, as: ExecutionRoute
  alias ExecutionPlane.Kernel.DispatchPlan
  alias ExecutionPlane.Protocols.{HTTP, JsonRpc}

  @spec build_dispatch(struct(), ExecutionRoute.t() | map() | keyword()) ::
          {:ok, DispatchPlan.t()} | {:error, Exception.t()}
  def build_dispatch(intent, route) do
    route = ExecutionRoute.new!(route)
    protocol_module = protocol_module_for(route.protocol)

    if is_nil(protocol_module) do
      {:error,
       ArgumentError.exception("unsupported lower protocol in Wave 1: #{inspect(route.protocol)}")}
    else
      {:ok,
       %DispatchPlan{
         route_id: route.route_id,
         family: route.family,
         protocol: route.protocol,
         protocol_module: protocol_module,
         route: route,
         intent: intent
       }}
    end
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec build_dispatch!(struct(), ExecutionRoute.t() | map() | keyword()) :: DispatchPlan.t()
  def build_dispatch!(intent, route) do
    case build_dispatch(intent, route) do
      {:ok, plan} -> plan
      {:error, error} -> raise error
    end
  end

  @spec protocol_module_for(String.t()) :: module() | nil
  def protocol_module_for("http"), do: HTTP
  def protocol_module_for("jsonrpc"), do: JsonRpc
  def protocol_module_for(_protocol), do: nil
end
