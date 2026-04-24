defmodule ExecutionPlane.Process.Application do
  @moduledoc """
  OTP application entry point for the standalone process runtime package.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: ExecutionPlane.TaskSupervisor}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: ExecutionPlane.Process.Supervisor
    )
  end
end
