defmodule ExecutionPlane.Node.ExecutionRegistry do
  @moduledoc false

  use GenServer

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def register(registry, execution_ref, worker, target_id, generation) do
    GenServer.call(
      registry,
      {:register, execution_ref, worker, target_id, generation}
    )
  end

  def lookup(registry, execution_ref), do: GenServer.call(registry, {:lookup, execution_ref})

  @impl true
  def init(_opts), do: {:ok, %{entries: %{}, monitors: %{}}}

  @impl true
  def handle_call({:register, ref, worker, target_id, generation}, _from, state) do
    if Map.has_key?(state.entries, ref) do
      {:reply, {:error, :execution_ref_conflict}, state}
    else
      monitor = Process.monitor(worker)
      entry = %{worker: worker, target_id: target_id, generation: generation}

      {:reply, :ok,
       %{
         state
         | entries: Map.put(state.entries, ref, entry),
           monitors: Map.put(state.monitors, monitor, ref)
       }}
    end
  end

  def handle_call({:lookup, ref}, _from, state) do
    case Map.fetch(state.entries, ref) do
      {:ok, entry} -> {:reply, {:ok, entry}, state}
      :error -> {:reply, {:error, :unknown_execution_ref}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, monitor, :process, _pid, _reason}, state) do
    case Map.pop(state.monitors, monitor) do
      {nil, _monitors} ->
        {:noreply, state}

      {ref, monitors} ->
        {:noreply, %{state | entries: Map.delete(state.entries, ref), monitors: monitors}}
    end
  end
end
