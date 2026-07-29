defmodule ExecutionPlane.Node.TargetClient.Adapter do
  @moduledoc """
  In-process Target client that dispatches through a host-registered lane adapter.
  """

  @behaviour ExecutionPlane.Target.Client

  @impl true
  def describe(opts), do: {:ok, %{lane_adapter: Keyword.get(opts, :lane_adapter)}}

  @impl true
  def execute(request, opts) do
    adapter = Keyword.fetch!(opts, :lane_adapter)

    with :ok <- adapter.validate(request) do
      adapter.execute(request, opts)
    end
  end

  @impl true
  def stream(request, opts) do
    adapter = Keyword.fetch!(opts, :lane_adapter)

    with :ok <- adapter.validate(request) do
      adapter.stream(request, opts)
    end
  end

  @impl true
  def cancel(execution_ref, opts) do
    adapter = Keyword.fetch!(opts, :lane_adapter)

    if function_exported?(adapter, :cancel, 2) do
      adapter.cancel(execution_ref, opts)
    else
      {:error, :lane_cancel_not_supported}
    end
  end

  def active_start(request, owner, opts) do
    adapter = Keyword.fetch!(opts, :lane_adapter)

    with :ok <- adapter.validate(request) do
      if function_exported?(adapter, :active_start, 3) do
        adapter.active_start(request, owner, opts)
      else
        start_legacy_task(adapter, request, owner, opts)
      end
    end
  end

  def active_send_input(handle, input, opts),
    do: active_lane_call(opts, :active_send_input, [handle, input, opts])

  def active_end_input(handle, opts),
    do: active_lane_call(opts, :active_end_input, [handle, opts])

  def active_cancel(handle, reason, opts) do
    adapter = Keyword.fetch!(opts, :lane_adapter)

    cond do
      function_exported?(adapter, :active_cancel, 3) ->
        adapter.active_cancel(handle, reason, opts)

      is_pid(handle) ->
        Process.exit(handle, :kill)
        :ok

      true ->
        {:error, :lane_cancel_not_supported}
    end
  end

  def active_event(handle, message, opts) do
    adapter = Keyword.fetch!(opts, :lane_adapter)

    if function_exported?(adapter, :active_event, 3) do
      adapter.active_event(handle, message, opts)
    else
      :ignore
    end
  end

  defp start_legacy_task(adapter, request, owner, opts) do
    Task.start(fn ->
      case adapter.execute(request, opts) do
        {:ok, result} ->
          send(owner, {:execution_plane_active, {:output, %{"execution_result" => result}}})
          send(owner, {:execution_plane_active, {:terminal, "completed", result}})

        {:error, %ExecutionPlane.ExecutionResult{} = result} ->
          send(owner, {:execution_plane_active, {:terminal, "failed", result}})

        {:error, reason} ->
          send(owner, {:execution_plane_active, {:error, reason}})
      end
    end)
  end

  defp active_lane_call(opts, callback, args) do
    adapter = Keyword.fetch!(opts, :lane_adapter)

    if function_exported?(adapter, callback, length(args)) do
      apply(adapter, callback, args)
    else
      {:error, :lane_active_lifecycle_not_supported}
    end
  end
end
