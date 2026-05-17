defmodule ExecutionPlane.Process.TransportSupervisor do
  @moduledoc false

  use DynamicSupervisor

  @default_app :execution_plane_process

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_child(module(), term()) :: DynamicSupervisor.on_start_child()
  def start_child(module, init_arg) when is_atom(module) do
    with :ok <- ensure_started() do
      DynamicSupervisor.start_child(__MODULE__, {module, init_arg})
    end
  catch
    :exit, {:noproc, _} -> {:error, :noproc}
    :exit, :noproc -> {:error, :noproc}
    :exit, reason -> {:error, {:transport_supervisor_exit, reason}}
  end

  defp ensure_started do
    case Application.ensure_all_started(@default_app) do
      {:ok, _started} -> :ok
      {:error, {:already_started, _app}} -> :ok
      {:error, reason} -> {:error, {:application_start_failed, reason}}
    end
  end
end
