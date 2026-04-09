defmodule ExecutionPlane.Runtimes.Process do
  @moduledoc """
  Minimal Wave 1 process-runtime shell.
  """

  alias ExecutionPlane.Contracts.ProcessExecutionIntent.V1, as: ProcessExecutionIntent

  @spec family() :: String.t()
  def family, do: "process"

  @spec supports_intent?(struct() | map() | keyword()) :: boolean()
  def supports_intent?(%ProcessExecutionIntent{}), do: true
  def supports_intent?(_other), do: false
end
