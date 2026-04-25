defmodule ExecutionPlane.ApplicationTest do
  use ExUnit.Case, async: false

  test "base application only owns the task supervisor in this wave" do
    children =
      ExecutionPlane.Supervisor
      |> Supervisor.which_children()
      |> Enum.map(fn {name, _pid, _type, _modules} -> name end)

    assert children == [ExecutionPlane.TaskSupervisor]
  end
end
