defmodule ExecutionPlane.Placements.SSH do
  @moduledoc """
  SSH-backed placement semantics for the execution-plane substrate.
  """

  alias ExecutionPlane.Placements.Surface

  @spec placement_family() :: String.t()
  def placement_family, do: "ssh"

  @spec supported_surface_kinds() :: [String.t(), ...]
  def supported_surface_kinds, do: ["ssh_exec"]

  @spec supports_surface?(Surface.t() | map() | keyword() | String.t() | atom()) :: boolean()
  def supports_surface?(surface), do: Surface.placement_family(surface) == placement_family()
end
