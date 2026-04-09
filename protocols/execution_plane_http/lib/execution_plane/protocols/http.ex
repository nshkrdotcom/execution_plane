defmodule ExecutionPlane.Protocols.HTTP do
  @moduledoc """
  Minimal Wave 1 lower HTTP package shell.
  """

  alias ExecutionPlane.Contracts.HttpExecutionIntent.V1, as: HttpExecutionIntent

  @spec protocol() :: String.t()
  def protocol, do: "http"

  @spec supported_stream_modes() :: [String.t(), ...]
  def supported_stream_modes, do: ["unary", "sse"]

  @spec supports_intent?(struct() | map() | keyword()) :: boolean()
  def supports_intent?(%HttpExecutionIntent{}), do: true
  def supports_intent?(_other), do: false
end
