defmodule ExecutionPlane.Node.ExecutionSupervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(_opts), do: DynamicSupervisor.init(strategy: :one_for_one)

  def start_worker(supervisor, args) do
    DynamicSupervisor.start_child(supervisor, {ExecutionPlane.Node.ExecutionWorker, args})
  catch
    :exit, {:noproc, _reason} -> {:error, :execution_supervisor_unavailable}
  end

  def terminate_worker(supervisor, worker) do
    DynamicSupervisor.terminate_child(supervisor, worker)
  catch
    :exit, {:noproc, _reason} -> :ok
  end
end
