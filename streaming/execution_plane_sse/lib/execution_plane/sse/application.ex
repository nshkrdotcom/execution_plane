defmodule ExecutionPlane.SSE.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: ExecutionPlane.SSE.TaskSupervisor}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: ExecutionPlane.SSE.Supervisor
    )
  end
end
