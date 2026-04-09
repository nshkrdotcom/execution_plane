defmodule ExecutionPlane.Protocols.JsonRpc do
  @moduledoc """
  Minimal Wave 1 lower JSON-RPC package shell.
  """

  alias ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntent

  @spec protocol() :: String.t()
  def protocol, do: "jsonrpc"

  @spec supports_intent?(struct() | map() | keyword()) :: boolean()
  def supports_intent?(%JsonRpcExecutionIntent{}), do: true
  def supports_intent?(_other), do: false
end
