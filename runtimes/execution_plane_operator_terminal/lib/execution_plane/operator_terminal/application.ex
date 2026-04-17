defmodule ExecutionPlane.OperatorTerminal.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: ExecutionPlane.OperatorTerminal.Registry},
      {DynamicSupervisor,
       strategy: :one_for_one, name: ExecutionPlane.OperatorTerminal.Supervisor}
    ]

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: ExecutionPlane.OperatorTerminal.RootSupervisor
    )
  end
end
