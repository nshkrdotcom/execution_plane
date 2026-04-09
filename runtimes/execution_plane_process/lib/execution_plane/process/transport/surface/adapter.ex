defmodule ExecutionPlane.Process.Transport.Surface.Adapter do
  @moduledoc """
  Internal behaviour for execution-surface adapters owned by the core.
  """

  alias ExecutionPlane.Process.Transport.Surface.Capabilities

  @type normalized_transport_options :: keyword()

  @callback surface_kind() :: ExecutionPlane.Process.Transport.Surface.adapter_surface_kind()
  @callback capabilities() :: Capabilities.t()
  @callback normalize_transport_options(term()) ::
              {:ok, normalized_transport_options()}
              | {:error, {:invalid_transport_options, term()}}
end
