defmodule ExecutionPlane.Process.Containment do
  @moduledoc """
  Opaque process-containment lifecycle.

  Containment is stronger than a process group: every descendant remains in
  the boundary even when it reparents, creates a new session, or changes its
  process group. Linux strict mode is implemented by
  `ExecutionPlane.Process.Containment.SystemdUser`.
  """

  @enforce_keys [:manager, :id]
  defstruct [:manager, :id, :control_group, metadata: %{}]

  @type t :: %__MODULE__{
          manager: module(),
          id: String.t(),
          control_group: String.t() | nil,
          metadata: map()
        }
end
