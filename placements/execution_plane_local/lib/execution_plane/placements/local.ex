defmodule ExecutionPlane.Placements.Local do
  @moduledoc """
  Minimal Wave 1 local-placement shell.
  """

  @spec placement_family() :: String.t()
  def placement_family, do: "local"

  @spec supported_surface_kinds() :: [String.t(), ...]
  def supported_surface_kinds, do: ["local_subprocess"]
end
