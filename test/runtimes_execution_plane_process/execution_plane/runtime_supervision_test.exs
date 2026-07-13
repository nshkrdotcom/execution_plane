defmodule ExecutionPlane.RuntimeSupervisionTest.SyntheticWeldedSupervisor do
  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl Supervisor
  def init(:ok) do
    Supervisor.init(
      [
        {Task.Supervisor, name: ExecutionPlane.TaskSupervisor},
        ExecutionPlane.Process.TransportSupervisor
      ],
      strategy: :one_for_one
    )
  end
end

defmodule ExecutionPlane.RuntimeSupervisionTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Process.TransportSupervisor
  alias ExecutionPlane.RuntimeSupervisionTest.SyntheticWeldedSupervisor
  alias ExecutionPlane.TaskSupport

  test "the same runtime source works under a synthetic welded supervisor" do
    runtime_owner_app = stop_runtime_owner_app!()

    {:ok, supervisor} = SyntheticWeldedSupervisor.start_link([])
    Process.unlink(supervisor)

    on_exit(fn ->
      stop_supervisor(supervisor)
      restart_runtime_owner_app!(runtime_owner_app)
    end)

    refute app_started?(runtime_owner_app)

    owner = self()
    assert {:ok, _pid} = TaskSupport.start_child(fn -> send(owner, :welded_task_started) end)

    assert {:ok, _pid} =
             TransportSupervisor.start_child(
               Task,
               fn -> send(owner, :welded_transport_child_started) end
             )

    assert_receive :welded_task_started, 250
    assert_receive :welded_transport_child_started, 250
    refute app_started?(runtime_owner_app)
  end

  test "missing supervisors return bounded errors without starting the component app" do
    runtime_owner_app = stop_runtime_owner_app!()
    on_exit(fn -> restart_runtime_owner_app!(runtime_owner_app) end)

    owner = self()

    assert {:error, {:runtime_not_started, :execution_plane_process}} =
             TaskSupport.start_child(fn -> send(owner, :unexpected_task_start) end)

    assert {:error, {:runtime_not_started, :execution_plane_process}} =
             TransportSupervisor.start_child(
               Task,
               fn -> send(owner, :unexpected_transport_child_start) end
             )

    refute_receive :unexpected_task_start, 50
    refute_receive :unexpected_transport_child_start, 50
    refute app_started?(runtime_owner_app)
  end

  test "selected runtime source starts only the real external erlexec application" do
    source_files = Path.wildcard("lib/**/*.ex") ++ Path.wildcard("lib/**/*.exs")

    Enum.each(source_files, fn path ->
      source = File.read!(path)

      refute Regex.match?(
               ~r/Application\.ensure_all_started\(\s*:execution_plane_process/,
               source
             ),
             "#{path} must use supervisor readiness instead of starting the component app"
    end)

    launcher =
      File.read!("lib/execution_plane/process/transport/subprocess/launcher.ex")

    assert String.contains?(launcher, "Application.ensure_all_started(:erlexec)")
  end

  defp stop_runtime_owner_app! do
    app = runtime_owner_app()

    case Application.stop(app) do
      :ok -> :ok
      {:error, {:not_started, ^app}} -> :ok
    end

    assert wait_until(fn ->
             is_nil(Process.whereis(ExecutionPlane.TaskSupervisor)) and
               is_nil(Process.whereis(TransportSupervisor))
           end)

    app
  end

  defp restart_runtime_owner_app!(app) do
    case Application.start(app) do
      :ok -> :ok
      {:error, {:already_started, ^app}} -> :ok
    end

    assert Process.whereis(ExecutionPlane.TaskSupervisor)
    assert Process.whereis(TransportSupervisor)
  end

  defp runtime_owner_app do
    if Application.spec(:execution_plane_process),
      do: :execution_plane_process,
      else: :execution_plane
  end

  defp stop_supervisor(supervisor) do
    if Process.alive?(supervisor) do
      Supervisor.stop(supervisor)
    end
  end

  defp app_started?(app) do
    Enum.any?(Application.started_applications(), fn {started_app, _description, _version} ->
      started_app == app
    end)
  end

  defp wait_until(predicate, attempts \\ 50)

  defp wait_until(predicate, attempts) when attempts > 0 do
    if predicate.() do
      true
    else
      Process.sleep(10)
      wait_until(predicate, attempts - 1)
    end
  end

  defp wait_until(predicate, 0), do: predicate.()
end
