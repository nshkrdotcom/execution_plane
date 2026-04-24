defmodule ExecutionPlane.TaskSupport do
  @moduledoc """
  Small task helpers shared by the runtime and transport layers.
  """

  @default_supervisor ExecutionPlane.TaskSupervisor
  @default_supervisor_apps [:execution_plane_process, :execution_plane]

  @type task_start_error ::
          :noproc | {:task_start_failed, term()} | {:application_start_failed, term()}

  @doc """
  Starts an unlinked task under the default task supervisor.
  """
  @spec async_nolink((-> any())) :: {:ok, Task.t()} | {:error, task_start_error()}
  def async_nolink(fun) when is_function(fun, 0) do
    async_nolink(@default_supervisor, fun)
  end

  @doc """
  Starts an unlinked task under a specific task supervisor.
  """
  @spec async_nolink(pid() | atom(), (-> any())) :: {:ok, Task.t()} | {:error, task_start_error()}
  def async_nolink(supervisor, fun) when is_function(fun, 0) do
    with :ok <- ensure_started_for(supervisor) do
      maybe_retry_noproc(supervisor, fn -> do_async_nolink(supervisor, fun) end)
    end
  end

  @doc """
  Starts a child task under the default task supervisor.
  """
  @spec start_child((-> any())) :: {:ok, pid()} | {:error, task_start_error()}
  def start_child(fun) when is_function(fun, 0) do
    start_child(@default_supervisor, fun)
  end

  @doc """
  Starts a child task under a specific task supervisor.
  """
  @spec start_child(pid() | atom(), (-> any())) :: {:ok, pid()} | {:error, task_start_error()}
  def start_child(supervisor, fun) when is_function(fun, 0) do
    with :ok <- ensure_started_for(supervisor) do
      maybe_retry_noproc(supervisor, fn -> do_start_child(supervisor, fun) end)
    end
  end

  @doc """
  Awaits a task result using the `Task.yield || Task.shutdown` pattern.
  """
  @spec await(Task.t(), timeout(), :brutal_kill | :shutdown) ::
          {:ok, term()} | {:exit, term()} | {:error, :timeout}
  def await(%Task{} = task, timeout \\ 5_000, shutdown \\ :brutal_kill) do
    case Task.yield(task, timeout) || Task.shutdown(task, shutdown) do
      {:ok, result} -> {:ok, result}
      {:exit, reason} -> {:exit, reason}
      nil -> {:error, :timeout}
    end
  end

  defp maybe_retry_noproc(@default_supervisor = supervisor, starter) do
    case starter.() do
      {:error, :noproc} ->
        with :ok <- ensure_started_for(supervisor) do
          starter.()
        end

      result ->
        result
    end
  end

  defp maybe_retry_noproc(_supervisor, starter), do: starter.()

  defp ensure_started_for(@default_supervisor) do
    @default_supervisor_apps
    |> Enum.reduce_while({:error, :no_runtime_app_started}, &ensure_candidate_started/2)
    |> case do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_started_for(_supervisor), do: :ok

  defp ensure_candidate_started(app, _acc) do
    if Application.spec(app) do
      app_start_result(app)
    else
      {:cont, {:error, {:application_not_found, app}}}
    end
  end

  defp app_start_result(app) do
    case Application.ensure_all_started(app) do
      {:ok, _started_apps} -> {:halt, :ok}
      {:error, reason} -> {:halt, {:error, {:application_start_failed, reason}}}
    end
  end

  defp do_async_nolink(supervisor, fun) do
    {:ok, Task.Supervisor.async_nolink(supervisor, fun)}
  catch
    :exit, {:noproc, _} ->
      {:error, :noproc}

    :exit, :noproc ->
      {:error, :noproc}

    :exit, reason ->
      {:error, {:task_start_failed, reason}}
  end

  defp do_start_child(supervisor, fun) do
    Task.Supervisor.start_child(supervisor, fun)
  catch
    :exit, {:noproc, _} ->
      {:error, :noproc}

    :exit, :noproc ->
      {:error, :noproc}

    :exit, reason ->
      {:error, {:task_start_failed, reason}}
  end
end
