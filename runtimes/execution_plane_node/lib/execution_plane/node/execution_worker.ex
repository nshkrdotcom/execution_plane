defmodule ExecutionPlane.Node.ExecutionWorker do
  @moduledoc false

  use GenServer, restart: :temporary

  alias ExecutionPlane.ExecutionRef
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Runtime.{Event, Status}

  @default_event_limit 256
  @default_cleanup_after_ms 60_000

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def subscribe(worker, subscriber, fence),
    do: GenServer.call(worker, {:subscribe, subscriber, fence})

  def send_input(worker, input, fence), do: GenServer.call(worker, {:send_input, input, fence})
  def end_input(worker, fence), do: GenServer.call(worker, {:end_input, fence})
  def status(worker, fence), do: GenServer.call(worker, {:status, fence})
  def cancel(worker, reason, fence), do: GenServer.call(worker, {:cancel, reason, fence})

  @impl true
  def init(args) do
    Process.flag(:trap_exit, true)

    state = %{
      execution_ref: Keyword.fetch!(args, :execution_ref),
      owner: Keyword.fetch!(args, :owner),
      request: Keyword.fetch!(args, :request),
      decision: Keyword.fetch!(args, :decision),
      node_id: Keyword.fetch!(args, :node_id),
      generation: Keyword.fetch!(args, :generation),
      target_client: Keyword.fetch!(args, :target_client),
      client_opts: Keyword.fetch!(args, :client_opts),
      lane_adapter: Keyword.fetch!(args, :lane_adapter),
      handle: nil,
      handle_monitor: nil,
      status: "accepted",
      input_open?: initial_input_open?(Keyword.fetch!(args, :request)),
      output_open?: true,
      sequence: 0,
      receipt_ref: nil,
      events: :queue.new(),
      event_count: 0,
      event_limit: Keyword.get(args, :event_limit, @default_event_limit),
      cleanup_after_ms: Keyword.get(args, :cleanup_after_ms, @default_cleanup_after_ms),
      subscribers: %{}
    }

    {:ok, state, {:continue, :start_effect}}
  end

  @impl true
  def handle_continue(:start_effect, state) do
    opts = Keyword.put(state.client_opts, :lane_adapter, state.lane_adapter)

    case start_effect(state, opts) do
      {:ok, handle} ->
        monitor = monitor_handle(handle)
        {:noreply, emit_started(%{state | handle: handle, handle_monitor: monitor})}

      {:error, reason} ->
        {:noreply, fail(state, reason)}
    end
  end

  @impl true
  def handle_call({:subscribe, subscriber, fence}, _from, state) do
    with :ok <- validate_fence(state, fence),
         true <- is_pid(subscriber) do
      monitor = Process.monitor(subscriber)
      Enum.each(:queue.to_list(state.events), &deliver(subscriber, state.execution_ref, &1))

      {:reply, :ok, %{state | subscribers: Map.put(state.subscribers, subscriber, monitor)}}
    else
      false -> {:reply, {:error, :invalid_subscriber}, state}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:send_input, input, fence}, _from, state) do
    with :ok <- validate_fence(state, fence),
         :ok <- require_input_open(state),
         :ok <-
           active_call(state.target_client, :active_send_input, [
             state.handle,
             input,
             active_opts(state)
           ]) do
      {:reply, :ok, state}
    else
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:end_input, fence}, _from, state) do
    with :ok <- validate_fence(state, fence),
         :ok <- require_input_open(state),
         :ok <-
           active_call(state.target_client, :active_end_input, [
             state.handle,
             active_opts(state)
           ]) do
      next_state =
        state
        |> Map.put(:input_open?, false)
        |> emit("input_closed", %{})

      {:reply, :ok, next_state}
    else
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:status, fence}, _from, state) do
    case validate_fence(state, fence) do
      :ok -> {:reply, {:ok, runtime_status(state)}, state}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:cancel, _reason, fence}, _from, %{receipt_ref: receipt} = state)
      when is_binary(receipt) do
    case validate_fence(state, fence) do
      :ok -> {:reply, :ok, state}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:cancel, reason, fence}, _from, state) do
    with :ok <- validate_fence(state, fence),
         :ok <-
           cancel_effect(state, reason) do
      {:reply, :ok, terminal(state, "cancelled", cancelled_result(state, reason))}
    else
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_info({:execution_plane_active, event}, state),
    do: {:noreply, handle_active_event(event, state)}

  def handle_info({:DOWN, monitor, :process, subscriber, _reason}, state) do
    cond do
      monitor == state.handle_monitor and is_nil(state.receipt_ref) ->
        {:noreply, fail(state, :lower_lifecycle_terminated)}

      Map.get(state.subscribers, subscriber) == monitor ->
        {:noreply, %{state | subscribers: Map.delete(state.subscribers, subscriber)}}

      true ->
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, _pid, :normal}, state), do: {:noreply, state}

  def handle_info({:EXIT, _pid, _reason}, %{receipt_ref: receipt} = state)
      when is_binary(receipt),
      do: {:noreply, state}

  def handle_info({:EXIT, _pid, reason}, state), do: {:noreply, fail(state, reason)}
  def handle_info(:cleanup, state), do: {:stop, :normal, state}

  def handle_info(message, state) do
    case active_call(state.target_client, :active_event, [
           state.handle,
           message,
           active_opts(state)
         ]) do
      {:ok, event} -> {:noreply, handle_active_event(event, state)}
      :ignore -> {:noreply, state}
      {:error, reason} -> {:noreply, fail(state, reason)}
    end
  end

  defp handle_active_event(_event, %{receipt_ref: receipt} = state) when is_binary(receipt),
    do: state

  defp handle_active_event({:output, payload}, state), do: emit(state, "output", payload)
  defp handle_active_event({:status, payload}, state), do: emit(state, "status", payload)

  defp handle_active_event({:terminal, terminal_state, %ExecutionResult{} = result}, state),
    do: terminal(state, terminal_state, result)

  defp handle_active_event({:error, reason}, state), do: fail(state, reason)
  defp handle_active_event(_event, state), do: state

  defp emit_started(state) do
    state
    |> Map.put(:status, "running")
    |> emit("started", %{
      "lane_id" => state.request.lane_id,
      "target_id" => state.decision.target_id,
      "generation" => state.generation
    })
  end

  defp emit(state, kind, payload) do
    if state.event_count >= state.event_limit do
      overflow(state)
    else
      event =
        Event.new!(%{
          execution_ref: ExecutionRef.new!(ref: state.execution_ref),
          sequence: state.sequence + 1,
          kind: kind,
          emitted_at: DateTime.utc_now(),
          payload: ExecutionPlane.Boundary.dump_value(payload)
        })

      Enum.each(Map.keys(state.subscribers), &deliver(&1, state.execution_ref, event))

      %{
        state
        | sequence: event.sequence,
          events: :queue.in(event, state.events),
          event_count: state.event_count + 1
      }
    end
  end

  defp terminal(%{receipt_ref: receipt} = state, _terminal_state, _result)
       when is_binary(receipt),
       do: state

  defp terminal(state, terminal_state, result) do
    receipt_ref = "receipt://execution-plane/#{state.execution_ref}/#{state.generation}"

    state =
      state
      |> Map.put(:status, terminal_state)
      |> Map.put(:input_open?, false)
      |> Map.put(:output_open?, false)
      |> Map.put(:receipt_ref, receipt_ref)
      |> emit("receipt", %{
        "receipt_ref" => receipt_ref,
        "terminal_state" => terminal_state,
        "execution_result" => result
      })

    send(
      state.owner,
      {:execution_plane_active_terminal, state.request.admission_request, state.decision, result}
    )

    Process.send_after(self(), :cleanup, state.cleanup_after_ms)
    state
  end

  defp fail(state, reason) do
    result =
      ExecutionResult.new!(
        execution_ref: state.execution_ref,
        status: "failed",
        error: %{"reason" => inspect(reason)},
        provenance: state.request.provenance
      )

    terminal(state, "failed", result)
  end

  defp overflow(%{receipt_ref: receipt} = state) when is_binary(receipt), do: state

  defp overflow(state) do
    _ =
      cancel_effect(state, "event_buffer_overflow")

    # The final receipt must fit, so discard the bounded replay buffer after
    # delivering the explicit backpressure signal to current subscribers.
    state = %{state | events: :queue.new(), event_count: 0, status: "backpressured"}
    state = emit(state, "backpressure", %{"limit" => state.event_limit})
    fail(state, :event_buffer_overflow)
  end

  defp runtime_status(state) do
    Status.new!(%{
      execution_ref: ExecutionRef.new!(ref: state.execution_ref),
      state: state.status,
      sequence: state.sequence,
      input_open: state.input_open?,
      output_open: state.output_open?,
      receipt_ref: state.receipt_ref
    })
  end

  defp cancelled_result(state, reason) do
    ExecutionResult.new!(
      execution_ref: state.execution_ref,
      status: "cancelled",
      error: %{"reason" => to_string(reason)},
      provenance: state.request.provenance
    )
  end

  defp deliver(subscriber, ref, event),
    do: send(subscriber, {:execution_plane_runtime, ref, event})

  defp validate_fence(state, fence) when fence in [nil, state.generation], do: :ok
  defp validate_fence(_state, _fence), do: {:error, :stale_execution_fence}

  defp require_input_open(%{input_open?: true, receipt_ref: nil}), do: :ok
  defp require_input_open(_state), do: {:error, :execution_input_closed}

  defp active_opts(state) do
    state.client_opts
    |> Keyword.put(:lane_adapter, state.lane_adapter)
    |> Keyword.put(:execution_ref, state.execution_ref)
  end

  defp initial_input_open?(%{lane_id: "process", payload: payload}) do
    request = Map.get(payload, "request", Map.get(payload, :request, %{}))
    stdin_mode = Map.get(request, "stdin_mode", Map.get(request, :stdin_mode))
    stdin_mode in ["pipe", "pty", :pipe, :pty]
  end

  defp initial_input_open?(_request), do: true

  defp monitor_handle(handle) when is_pid(handle), do: Process.monitor(handle)

  defp monitor_handle(%{monitor_pid: monitor_pid}) when is_pid(monitor_pid),
    do: Process.monitor(monitor_pid)

  defp monitor_handle(_handle), do: nil

  defp cancel_effect(state, reason) do
    cond do
      Code.ensure_loaded?(state.target_client) and
          function_exported?(state.target_client, :active_cancel, 3) ->
        active_call(state.target_client, :active_cancel, [
          state.handle,
          reason,
          active_opts(state)
        ])

      Code.ensure_loaded?(state.target_client) and
          function_exported?(state.target_client, :cancel, 2) ->
        result =
          state.target_client.cancel(
            ExecutionRef.new!(ref: state.execution_ref),
            active_opts(state)
          )

        if is_pid(state.handle) and Process.alive?(state.handle),
          do: Process.exit(state.handle, :kill)

        result

      true ->
        {:error, :active_cancel_not_supported}
    end
  end

  defp start_effect(state, opts) do
    if Code.ensure_loaded?(state.target_client) and
         function_exported?(state.target_client, :active_start, 3) do
      active_call(state.target_client, :active_start, [state.request, self(), opts])
    else
      start_legacy_effect(state, opts)
    end
  end

  defp start_legacy_effect(state, opts) do
    owner = self()

    Task.start(fn ->
      case state.target_client.execute(state.request, opts) do
        {:ok, %ExecutionResult{} = result} ->
          send(owner, {:execution_plane_active, {:output, %{"execution_result" => result}}})
          send(owner, {:execution_plane_active, {:terminal, "completed", result}})

        {:error, %ExecutionResult{} = result} ->
          send(owner, {:execution_plane_active, {:terminal, "failed", result}})

        {:error, reason} ->
          send(owner, {:execution_plane_active, {:error, reason}})
      end
    end)
  end

  defp active_call(module, callback, args) do
    if Code.ensure_loaded?(module) and function_exported?(module, callback, length(args)) do
      apply(module, callback, args)
    else
      {:error, :active_lifecycle_not_supported}
    end
  rescue
    error -> {:error, {:active_lifecycle_exception, Exception.message(error)}}
  catch
    kind, reason -> {:error, {:active_lifecycle_throw, kind, reason}}
  end
end
