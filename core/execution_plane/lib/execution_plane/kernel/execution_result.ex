defmodule ExecutionPlane.Kernel.ExecutionResult do
  @moduledoc """
  Result bundle returned by the minimal execution-plane kernel.
  """

  alias ExecutionPlane.Contracts.ExecutionEvent.V1, as: ExecutionEvent
  alias ExecutionPlane.Contracts.ExecutionOutcome.V1, as: ExecutionOutcome
  alias ExecutionPlane.Kernel.DispatchPlan

  defstruct [:plan, :outcome, events: []]

  @type t :: %__MODULE__{
          plan: DispatchPlan.t(),
          events: [ExecutionEvent.t()],
          outcome: ExecutionOutcome.t()
        }
end
