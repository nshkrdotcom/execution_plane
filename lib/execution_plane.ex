defmodule ExecutionPlane do
  @moduledoc """
  Lower-runtime substrate for shared execution contracts and runtime helpers.
  """

  @package_homes %{
    root_common: ".",
    http: "protocols/execution_plane_http",
    jsonrpc: "protocols/execution_plane_jsonrpc",
    sse: "streaming/execution_plane_sse",
    websocket: "streaming/execution_plane_websocket",
    local: "placements/execution_plane_local",
    ssh: "placements/execution_plane_ssh",
    guest: "placements/execution_plane_guest",
    node: "runtimes/execution_plane_node",
    process: "runtimes/execution_plane_process",
    operator_terminal: "runtimes/execution_plane_operator_terminal",
    testkit: "conformance/execution_plane_testkit"
  }

  @active_mix_projects ~w(
    execution_plane
    execution_plane_http
    execution_plane_jsonrpc
    execution_plane_sse
    execution_plane_websocket
    execution_plane_process
    execution_plane_node
    execution_plane_operator_terminal
  )a

  @doc """
  Returns the root identity for the workspace shell.

  ## Examples

      iex> ExecutionPlane.identity()
      :execution_plane

  """
  @spec identity() :: :execution_plane
  def identity, do: :execution_plane

  @doc """
  Returns the active package homes keyed by their runtime role.
  """
  @spec package_homes() :: %{required(atom()) => String.t()}
  def package_homes, do: @package_homes

  @doc """
  Returns the final active Mix project app names.
  """
  @spec minimal_first_cut() :: [atom(), ...]
  def minimal_first_cut, do: @active_mix_projects

  @doc """
  Returns the final active Mix project app names.
  """
  @spec active_mix_projects() :: [atom(), ...]
  def active_mix_projects, do: @active_mix_projects
end
