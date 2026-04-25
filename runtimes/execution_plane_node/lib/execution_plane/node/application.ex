defmodule ExecutionPlane.Node.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ExecutionPlane.Node.Server, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ExecutionPlane.Node.Supervisor)
  end
end
