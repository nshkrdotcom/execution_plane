defmodule ExecutionPlane.OperatorTerminal.Info do
  @moduledoc """
  Snapshot of one operator-terminal ingress instance.
  """

  alias ExecutionPlane.OperatorTerminal.Surface

  @enforce_keys [:terminal_id, :mod, :surface_kind, :status]
  defstruct terminal_id: nil,
            mod: nil,
            surface_kind: nil,
            surface_ref: nil,
            boundary_class: nil,
            observability: %{},
            transport_options: %{},
            adapter_metadata: %{},
            status: :running

  @type status :: :running | :stopped

  @type t :: %__MODULE__{
          terminal_id: String.t(),
          mod: module(),
          surface_kind: Surface.surface_kind(),
          surface_ref: String.t() | nil,
          boundary_class: Surface.boundary_class(),
          observability: map(),
          transport_options: map(),
          adapter_metadata: map(),
          status: status()
        }
end
