defmodule ExecutionPlane do
  @moduledoc """
  Lower-runtime substrate for shared execution contracts and runtime helpers.
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
  Returns the published package homes keyed by their runtime role.
  """
  @spec package_homes() :: %{required(atom()) => String.t()}
  def package_homes, do: @package_homes

  @doc """
  Returns the minimal executable substrate package roles.
  """
  @spec minimal_first_cut() :: [atom(), ...]
  def minimal_first_cut, do: @minimal_first_cut
end
