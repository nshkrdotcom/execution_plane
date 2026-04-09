defmodule ExecutionPlane.Placements.Guest do
  @moduledoc """
  Guest-backed placement semantics for the execution-plane substrate.
  """

  alias ExecutionPlane.Placements.Surface

  @spec placement_family() :: String.t()
  def placement_family, do: "guest"

  @spec supported_surface_kinds() :: [String.t(), ...]
  def supported_surface_kinds, do: ["guest_bridge"]

  @spec supports_surface?(Surface.t() | map() | keyword() | String.t() | atom()) :: boolean()
  def supports_surface?(surface), do: Surface.placement_family(surface) == placement_family()
end
