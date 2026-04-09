defmodule ExecutionPlane.Kernel.DispatchPlan do
  @moduledoc """
  Minimal Wave 1 dispatch plan produced from a validated route and lower intent.
  """

  defstruct [:route_id, :family, :protocol, :protocol_module, :route, :intent]

  @type t :: %__MODULE__{
          route_id: String.t(),
          family: String.t(),
          protocol: String.t(),
          protocol_module: module(),
          route: struct(),
          intent: struct()
        }
end
