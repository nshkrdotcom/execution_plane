defmodule ExecutionPlane do
  @moduledoc """
  Workspace shell for the Execution Plane lower-runtime substrate.

  Wave 1 freezes the package map and cross-layer contracts without pretending
  the lower runtime extraction is already complete.
  """

  @package_homes %{
    contracts: "core/execution_plane_contracts",
    kernel: "core/execution_plane_kernel",
    http: "protocols/execution_plane_http",
    jsonrpc: "protocols/execution_plane_jsonrpc",
    sse: "streaming/execution_plane_sse",
    websocket: "streaming/execution_plane_websocket",
    local: "placements/execution_plane_local",
    ssh: "placements/execution_plane_ssh",
    guest: "placements/execution_plane_guest",
    process: "runtimes/execution_plane_process",
    operator_terminal: "runtimes/execution_plane_operator_terminal",
    container: "sandboxes/execution_plane_container",
    microvm: "sandboxes/execution_plane_microvm",
    testkit: "conformance/execution_plane_testkit"
  }

  @minimal_first_cut ~w(contracts kernel http jsonrpc local process testkit)a

  @doc """
  Returns the root identity for the workspace shell.

  ## Examples

      iex> ExecutionPlane.identity()
      :execution_plane

  """
  @spec identity() :: :execution_plane
  def identity, do: :execution_plane

  @doc """
  Returns the tracked workspace package homes keyed by their architecture role.
  """
  @spec package_homes() :: %{required(atom()) => String.t()}
  def package_homes, do: @package_homes

  @doc """
  Returns the minimal first-cut package roles required by Wave 1.
  """
  @spec minimal_first_cut() :: [atom(), ...]
  def minimal_first_cut, do: @minimal_first_cut
end
