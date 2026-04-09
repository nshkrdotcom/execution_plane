defmodule ExecutionPlane do
  @moduledoc """
  Root namespace for the Execution Plane runtime substrate.

  The initial public scaffold keeps the API intentionally small while the
  execution-plane contract and runtime packages are developed.
  """

  @doc """
  Returns the root identity for the package.

  ## Examples

      iex> ExecutionPlane.identity()
      :execution_plane

  """
  @spec identity() :: :execution_plane
  def identity, do: :execution_plane
end
