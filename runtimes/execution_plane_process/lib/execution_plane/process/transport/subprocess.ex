defmodule ExecutionPlane.Process.Transport.Subprocess do
  @moduledoc false

  use GenServer

  import Kernel, except: [send: 2]

  alias ExecutionPlane.{LineFraming, ProcessExit, TaskSupport}
  alias ExecutionPlane.Process.Transport
  alias ExecutionPlane.Process.Transport.{Error, Info, Options, RunOptions, RunResult}

  alias ExecutionPlane.Process.Transport.Subprocess.{
    Framing,
    Launcher,
    RequestTracker,
    SignalControl,
    State,
    SubscriberRegistry
  }

  alias ExecutionPlane.Process.TransportSupervisor

  @behaviour Transport

  @default_call_timeout_ms 5_000
  @default_force_close_timeout_ms 5_000
  @default_finalize_delay_ms 25
  @default_max_lines_per_batch 200

  @spec child_spec(Options.t()) :: Supervisor.child_spec()
  def child_spec(%Options{} = init_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [init_arg]},
      restart: :temporary,
      shutdown: 5_000,
      type: :worker
    }
  end

  @impl Transport
  def start(opts) when is_list(opts) do
    case Options.new(opts) do
      {:ok, options} ->
        with :ok <- maybe_preflight_startup(options),
             {:ok, pid} <- TransportSupervisor.start_child(__MODULE__, options) do
          {:ok, pid}
        else
          {:error, %Error{} = error} -> transport_error(error)
          {:error, reason} -> transport_error(reason)
        end

      {:error, {:invalid_transport_options, reason}} ->
        transport_error(Error.invalid_options(reason))
    end
  catch
    :exit, reason ->
      transport_error(reason)
  end

  @impl Transport
  def start_link(opts) when is_list(opts), do: start(opts)

  @doc false
  def start_link(%Options{} = options) do
    with :ok <- maybe_preflight_startup(options),
         {:ok, pid} <- GenServer.start_link(__MODULE__, options) do
      {:ok, pid}
    else
      {:error, %Error{} = error} -> transport_error(error)
      {:error, reason} -> transport_error(reason)
    end
  catch
    :exit, reason ->
      transport_error(reason)
  end

  @impl Transport
  def run(%ExecutionPlane.Command{} = command, opts) when is_list(opts) do
    with {:ok, options} <- RunOptions.new(command, opts),
         :ok <- Launcher.validate_cwd_exists(options.command.cwd),
         :ok <- Launcher.validate_command_exists(options.command.command),
         :ok <- Launcher.ensure_erlexec_started(options.os),
         exec_opts <-
           Launcher.build_exec_opts(
             options.command.cwd,
             options.command.env,
             options.command.clear_env?,
             options.command.user,
             false
           ),
         argv <- Launcher.normalize_command_argv(options.command.command, options.command.args),
         {:ok, pid, os_pid} <- Launcher.exec_run(options.command.command, argv, exec_opts) do
      run_started_exec(pid, os_pid, options)
    else
      {:error, {:invalid_run_options, reason}} ->
        transport_error(Error.invalid_options(reason))

      {:error, %Error{} = error} ->
        transport_error(error)
    end
  end

  @impl Transport
  def send(transport, message) when is_pid(transport) do
    case safe_call(transport, {:send, message}) do
      {:ok, result} -> result
      {:error, reason} -> transport_error(reason)
    end
  end

  @impl Transport
  def subscribe(transport, pid) when is_pid(transport) and is_pid(pid) do
    subscribe_with_tag(transport, pid, pid)
  end

  @impl Transport
  def subscribe(transport, pid, tag)
      when is_pid(transport) and is_pid(pid) and is_reference(tag),
      do: subscribe_with_tag(transport, pid, tag)

  def subscribe(_transport, _pid, tag) do
    transport_error(Error.invalid_options({:invalid_subscriber, tag}))
  end

  @impl Transport
  def unsubscribe(transport, pid) when is_pid(transport) and is_pid(pid) do
    case safe_call(transport, {:unsubscribe, pid}) do
      {:ok, :ok} -> :ok
      {:error, _reason} -> :ok
    end
  end

  @impl Transport
  def close(transport) when is_pid(transport) do
    GenServer.stop(transport, :normal)
  catch
    :exit, {:noproc, _} -> :ok
    :exit, :noproc -> :ok
  end

  @impl Transport
  def force_close(transport) when is_pid(transport) do
    do_force_close(transport, @default_force_close_timeout_ms)
  end

  @impl Transport
  def interrupt(transport) when is_pid(transport) do
    case safe_call(transport, :interrupt) do
      {:ok, result} ->
        normalize_call_result(result)

      {:error, reason} ->
        transport_error(reason)
    end
  end

  @impl Transport
  def status(transport) when is_pid(transport) do
    case safe_call(transport, :status) do
      {:ok, status} when status in [:connected, :disconnected, :error] -> status
      {:ok, _other} -> :error
      {:error, _reason} -> :disconnected
    end
  end

  @impl Transport
  def end_input(transport) when is_pid(transport) do
    case safe_call(transport, :end_input) do
      {:ok, result} -> result
      {:error, reason} -> transport_error(reason)
    end
  end

  @impl Transport
  def stderr(transport) when is_pid(transport) do
    case safe_call(transport, :stderr) do
      {:ok, data} when is_binary(data) -> data
      _ -> ""
    end
  end

  @impl Transport
  def info(transport) when is_pid(transport) do
    case safe_call(transport, :info) do
      {:ok, %Info{} = info} -> info
      _other -> Info.disconnected()
    end
  end

  @impl GenServer
  def init(%Options{} = options) do
    state = State.new(options)

    case options.startup_mode do
      :lazy ->
        {:ok, maybe_schedule_headless_timer(state), {:continue, :start_subprocess}}

      :eager ->
        case start_subprocess(state, options) do
          {:ok, connected_state} -> {:ok, connected_state}
          {:error, reason} -> {:stop, reason}
        end
    end
  end

  @impl GenServer
  def handle_continue(:start_subprocess, %{startup_options: %Options{} = options} = state) do
    case start_subprocess(state, options) do
      {:ok, connected_state} ->
        {:noreply, connected_state}

      {:error, reason} ->
        {:stop, reason, %{state | startup_options: nil}}
    end
  end

  @impl GenServer
  def handle_call({:subscribe, pid, tag}, _from, state) do
    first_subscriber? = map_size(state.subscribers) == 0

    state =
      state
      |> put_subscriber(pid, tag)
      |> maybe_replay_buffered_events_to_subscriber(pid, first_subscriber?)
      |> maybe_replay_stderr_to_subscriber(pid)

    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, pid}, _from, state) do
    {:reply, :ok, remove_subscriber(state, pid)}
  end

  def handle_call({:send, message}, from, %{subprocess: {pid, _os_pid}} = state) do
    case start_io_task(state, fn -> SignalControl.send_payload(pid, message, state.stdin_mode) end) do
      {:ok, task} ->
        {:noreply, RequestTracker.put(state, task.ref, from)}

      {:error, reason} ->
        {:reply, transport_error(reason), state}
    end
  end

  def handle_call({:send, _message}, _from, state) do
    {:reply, transport_error(Error.not_connected()), state}
  end

  def handle_call(:status, _from, state), do: {:reply, state.status, state}

  def handle_call(:stderr, _from, state), do: {:reply, state.stderr_buffer, state}

  def handle_call(:info, _from, state), do: {:reply, transport_info(state), state}

  def handle_call(:end_input, from, %{subprocess: {pid, _os_pid}} = state) do
    case start_io_task(state, fn -> SignalControl.end_input(pid, state.pty?) end) do
      {:ok, task} ->
        {:noreply, RequestTracker.put(state, task.ref, from)}

      {:error, reason} ->
        {:reply, transport_error(reason), state}
    end
  end

  def handle_call(:end_input, _from, state) do
    {:reply, transport_error(Error.not_connected()), state}
  end

  def handle_call(:interrupt, from, %{subprocess: {pid, os_pid}} = state) do
    case start_io_task(state, fn ->
           SignalControl.interrupt(pid, os_pid, state.interrupt_mode, state.os)
         end) do
      {:ok, task} ->
        {:noreply, RequestTracker.put(state, task.ref, from)}

      {:error, reason} ->
        {:reply, transport_error(reason), state}
    end
  end

  def handle_call(:interrupt, _from, state) do
    {:reply, transport_error(Error.not_connected()), state}
  end

  def handle_call(:force_close, _from, state) do
    state = force_stop_subprocess(state)
    {:stop, :normal, :ok, state}
  end

  @impl GenServer
  def handle_info(
        {:stdout, os_pid, chunk},
        %{subprocess: {_pid, os_pid}, stdout_mode: :raw} = state
      ) do
    state = append_stdout_chunk(state, IO.iodata_to_binary(chunk))
    maybe_stop_after_fatal(state)
  end

  @impl GenServer
  def handle_info({:stdout, os_pid, chunk}, %{subprocess: {_pid, os_pid}} = state) do
    state =
      state
      |> append_stdout_chunk(IO.iodata_to_binary(chunk))
      |> drain_stdout_lines(@default_max_lines_per_batch)
      |> maybe_schedule_drain()

    maybe_stop_after_fatal(state)
  end

  def handle_info({:stderr, os_pid, chunk}, %{subprocess: {_pid, os_pid}} = state) do
    {:noreply, append_stderr_chunk(state, IO.iodata_to_binary(chunk))}
  end

  def handle_info({ref, result}, state) when is_reference(ref) do
    case RequestTracker.pop(state, ref) do
      {nil, state} ->
        {:noreply, state}

      {from, state} ->
        Process.demonitor(ref, [:flush])
        GenServer.reply(from, normalize_call_result(result))
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, os_pid, :process, pid, reason}, %{subprocess: {pid, os_pid}} = state) do
    state = cancel_finalize_timer(state)

    timer_ref =
      Process.send_after(
        self(),
        {:finalize_exit, os_pid, pid, reason},
        @default_finalize_delay_ms
      )

    {:noreply, %{state | finalize_timer_ref: timer_ref}}
  end

  def handle_info({:finalize_exit, os_pid, pid, reason}, %{subprocess: {pid, os_pid}} = state) do
    state =
      state
      |> Map.put(:finalize_timer_ref, nil)
      |> Map.put(:drain_scheduled?, false)
      |> flush_exit_mailbox(pid, os_pid)
      |> drain_stdout_lines(@default_max_lines_per_batch)

    if :queue.is_empty(state.pending_lines) do
      state = flush_stdout_fragment(state)
      state = flush_stderr_fragment(state)

      if state.fatal_stop_scheduled? do
        {:stop, :normal, state}
      else
        state =
          emit_event(state, {:exit, ProcessExit.from_reason(reason, stderr: state.stderr_buffer)})

        {:stop, :normal, %{state | status: :disconnected, subprocess: nil}}
      end
    else
      Kernel.send(self(), {:finalize_exit, os_pid, pid, reason})
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state) when is_reference(ref) do
    case RequestTracker.pop(state, ref) do
      {from, state} when not is_nil(from) ->
        GenServer.reply(from, transport_error(Error.send_failed(reason)))
        {:noreply, state}

      {nil, state} ->
        {:noreply, handle_subscriber_down(ref, pid, state)}
    end
  end

  def handle_info(:drain_stdout, state) do
    state =
      state
      |> Map.put(:drain_scheduled?, false)
      |> drain_stdout_lines(@default_max_lines_per_batch)
      |> maybe_schedule_drain()

    maybe_stop_after_fatal(state)
  end

  def handle_info(:headless_timeout, state) do
    state = %{state | headless_timer_ref: nil}

    if map_size(state.subscribers) == 0 and not is_nil(state.subprocess) do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info(_other, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, state) do
    state =
      state
      |> cancel_finalize_timer()
      |> cancel_headless_timer()
      |> cleanup_long_line_spool()

    SubscriberRegistry.demonitor(state.subscribers)

    RequestTracker.cleanup(state.pending_calls, fn :transport_stopped ->
      transport_error(Error.transport_stopped())
    end)

    _ = force_stop_subprocess(state)
    :ok
  catch
    _, _ -> :ok
  end

  defp safe_call(transport, message, timeout \\ @default_call_timeout_ms)

  defp safe_call(transport, message, timeout)
       when is_pid(transport) and is_integer(timeout) and timeout >= 0 do
    case TaskSupport.async_nolink(fn ->
           try do
             {:ok, GenServer.call(transport, message, :infinity)}
           catch
             :exit, reason -> {:error, normalize_call_exit(reason)}
           end
         end) do
      {:ok, task} ->
        await_task_result(task, timeout)

      {:error, reason} ->
        {:error, normalize_call_task_start_error(reason)}
    end
  end

  defp await_task_result(task, timeout) do
    case TaskSupport.await(task, timeout, :brutal_kill) do
      {:ok, result} -> result
      {:exit, reason} -> {:error, normalize_call_exit(reason)}
      {:error, :timeout} -> {:error, Error.timeout()}
    end
  end

  defp normalize_call_task_start_error(:noproc), do: Error.transport_stopped()
  defp normalize_call_task_start_error(reason), do: Error.call_exit(reason)

  defp normalize_call_exit({:noproc, _}), do: Error.not_connected()
  defp normalize_call_exit(:noproc), do: Error.not_connected()
  defp normalize_call_exit({:normal, _}), do: Error.not_connected()
  defp normalize_call_exit({:shutdown, _}), do: Error.not_connected()
  defp normalize_call_exit({:timeout, _}), do: Error.timeout()
  defp normalize_call_exit(reason), do: Error.call_exit(reason)

  defp normalize_call_result(:ok), do: :ok
  defp normalize_call_result({:error, {:transport, %Error{}}} = error), do: error
  defp normalize_call_result({:error, %Error{} = error}), do: transport_error(error)
  defp normalize_call_result({:error, reason}), do: transport_error(reason)

  defp normalize_call_result(other),
    do: transport_error(Error.transport_error({:unexpected_task_result, other}))

  defp do_force_close(transport, timeout_ms)
       when is_pid(transport) and is_integer(timeout_ms) and timeout_ms >= 0 do
    GenServer.stop(transport, :normal, timeout_ms)
    :ok
  catch
    :exit, reason ->
      transport_error(normalize_force_close_exit(reason))
  end

  defp normalize_force_close_exit({:noproc, _}), do: Error.not_connected()
  defp normalize_force_close_exit(:noproc), do: Error.not_connected()
  defp normalize_force_close_exit({:normal, _}), do: Error.not_connected()
  defp normalize_force_close_exit({:shutdown, _}), do: Error.not_connected()
  defp normalize_force_close_exit({:timeout, {GenServer, :stop, _}}), do: Error.timeout()
  defp normalize_force_close_exit({:timeout, _}), do: Error.timeout()
  defp normalize_force_close_exit(reason), do: Error.call_exit(reason)

  defp maybe_preflight_startup(%Options{startup_mode: :lazy} = options),
    do: Launcher.preflight(options)

  defp maybe_preflight_startup(%Options{}), do: :ok

  defp start_subprocess(state, %Options{} = options) do
    with {:ok, state} <- add_bootstrap_subscriber(state, options.subscriber),
         {:ok, pid, os_pid} <- Launcher.start(options) do
      state = connected_state(state, pid, os_pid)
      {:ok, maybe_schedule_headless_timer(%{state | startup_options: nil})}
    end
  end

  defp run_started_exec(pid, os_pid, %RunOptions{} = options) do
    case maybe_send_run_input(pid, options.stdin, options.close_stdin) do
      :ok ->
        collect_run_output(
          pid,
          os_pid,
          options,
          timeout_deadline(options.timeout),
          [],
          [],
          []
        )

      {:error, {:transport, %Error{}} = error} ->
        SignalControl.stop_run_and_confirm_down(pid, os_pid, options.os)
        _ = flush_run_messages(pid, os_pid, options.stderr, [], [], [])
        {:error, error}
    end
  end

  defp maybe_send_run_input(pid, nil, true), do: SignalControl.send_eof(pid)
  defp maybe_send_run_input(_pid, nil, false), do: :ok

  defp maybe_send_run_input(pid, stdin, close_stdin) do
    with {:ok, payload} <- normalize_run_input(stdin),
         :ok <- SignalControl.send_payload(pid, payload, :raw) do
      maybe_send_run_eof(pid, close_stdin)
    end
  end

  defp maybe_send_run_eof(_pid, false), do: :ok
  defp maybe_send_run_eof(pid, true), do: SignalControl.send_eof(pid)

  defp normalize_run_input(stdin) do
    {:ok, SignalControl.normalize_payload(stdin)}
  rescue
    error ->
      transport_error(Error.send_failed({:invalid_input, error}))
  catch
    kind, reason ->
      transport_error(Error.send_failed({kind, reason}))
  end

  defp collect_run_output(pid, os_pid, options, :infinity, stdout, stderr, output) do
    receive do
      {:stdout, ^os_pid, data} ->
        data = IO.iodata_to_binary(data)

        collect_run_output(
          pid,
          os_pid,
          options,
          :infinity,
          [data | stdout],
          stderr,
          [data | output]
        )

      {:stderr, ^os_pid, data} ->
        data = IO.iodata_to_binary(data)
        output = merge_stderr_output(data, output, options.stderr)
        collect_run_output(pid, os_pid, options, :infinity, stdout, [data | stderr], output)

      {:DOWN, ^os_pid, :process, ^pid, reason} ->
        build_run_result_after_down(pid, os_pid, reason, options, stdout, stderr, output)
    end
  end

  defp collect_run_output(pid, os_pid, options, deadline_ms, stdout, stderr, output)
       when is_integer(deadline_ms) do
    case timeout_remaining(deadline_ms) do
      :expired ->
        handle_run_timeout(pid, os_pid, options, stdout, stderr, output)

      remaining_timeout ->
        receive do
          {:stdout, ^os_pid, data} ->
            data = IO.iodata_to_binary(data)

            collect_run_output(
              pid,
              os_pid,
              options,
              deadline_ms,
              [data | stdout],
              stderr,
              [data | output]
            )

          {:stderr, ^os_pid, data} ->
            data = IO.iodata_to_binary(data)
            output = merge_stderr_output(data, output, options.stderr)
            collect_run_output(pid, os_pid, options, deadline_ms, stdout, [data | stderr], output)

          {:DOWN, ^os_pid, :process, ^pid, reason} ->
            build_run_result_after_down(pid, os_pid, reason, options, stdout, stderr, output)
        after
          remaining_timeout ->
            handle_run_timeout(pid, os_pid, options, stdout, stderr, output)
        end
    end
  end

  defp build_run_result_after_down(pid, os_pid, reason, options, stdout, stderr, output) do
    {stdout, stderr, output} =
      flush_run_messages(pid, os_pid, options.stderr, stdout, stderr, output)

    exit = ProcessExit.from_reason(reason, stderr: chunks_to_binary(stderr))
    {:ok, build_run_result(options.command, options.stderr, stdout, stderr, output, exit)}
  end

  defp handle_run_timeout(pid, os_pid, options, stdout, stderr, output) do
    SignalControl.stop_run_and_confirm_down(pid, os_pid, options.os)

    {stdout, stderr, output} =
      flush_run_messages(pid, os_pid, options.stderr, stdout, stderr, output)

    transport_error(
      Error.transport_error(:timeout, %{
        command: options.command.command,
        args: options.command.args,
        stdout: chunks_to_binary(stdout),
        stderr: chunks_to_binary(stderr),
        output: chunks_to_binary(output)
      })
    )
  end

  defp build_run_result(command, stderr_mode, stdout, stderr, output, %ProcessExit{} = exit) do
    %RunResult{
      invocation: command,
      stdout: chunks_to_binary(stdout),
      stderr: chunks_to_binary(stderr),
      output: chunks_to_binary(output),
      exit: exit,
      stderr_mode: stderr_mode
    }
  end

  defp merge_stderr_output(data, output, :stdout), do: [data | output]
  defp merge_stderr_output(_data, output, :separate), do: output

  defp chunks_to_binary(chunks) when is_list(chunks) do
    chunks
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp flush_run_messages(pid, os_pid, stderr_mode, stdout, stderr, output) do
    receive do
      {:stdout, ^os_pid, data} ->
        flush_run_messages(
          pid,
          os_pid,
          stderr_mode,
          [IO.iodata_to_binary(data) | stdout],
          stderr,
          [IO.iodata_to_binary(data) | output]
        )

      {:stderr, ^os_pid, data} ->
        data = IO.iodata_to_binary(data)
        output = merge_stderr_output(data, output, stderr_mode)
        flush_run_messages(pid, os_pid, stderr_mode, stdout, [data | stderr], output)

      {:DOWN, ^os_pid, :process, ^pid, _reason} ->
        flush_run_messages(pid, os_pid, stderr_mode, stdout, stderr, output)
    after
      0 ->
        {stdout, stderr, output}
    end
  end

  defp timeout_deadline(:infinity), do: :infinity
  defp timeout_deadline(timeout_ms), do: System.monotonic_time(:millisecond) + timeout_ms

  defp timeout_remaining(deadline_ms) do
    remaining = deadline_ms - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      :expired
    else
      remaining
    end
  end

  defp connected_state(state, pid, os_pid) do
    %{state | subprocess: {pid, os_pid}, status: :connected}
  end

  defp transport_info(state) do
    {pid, os_pid} =
      case state.subprocess do
        {subprocess_pid, subprocess_os_pid} -> {subprocess_pid, subprocess_os_pid}
        _other -> {nil, nil}
      end

    %Info{
      invocation: state.invocation,
      pid: pid,
      os_pid: os_pid,
      surface_kind: state.surface_kind,
      target_id: state.target_id,
      lease_ref: state.lease_ref,
      surface_ref: state.surface_ref,
      boundary_class: state.boundary_class,
      observability: state.observability,
      adapter_capabilities: state.adapter_capabilities,
      effective_capabilities: state.effective_capabilities,
      bridge_profile: state.bridge_profile,
      protocol_version: state.protocol_version,
      extensions: state.extensions,
      adapter_metadata: state.adapter_metadata,
      status: state.status,
      stdout_mode: state.stdout_mode,
      stdin_mode: state.stdin_mode,
      pty?: state.pty?,
      interrupt_mode: state.interrupt_mode,
      stderr: state.stderr_buffer,
      delivery: Transport.Delivery.new(state.event_tag)
    }
  end

  defp add_bootstrap_subscriber(state, nil), do: {:ok, state}

  defp add_bootstrap_subscriber(state, pid) when is_pid(pid),
    do: {:ok, state |> put_subscriber(pid, pid) |> maybe_replay_stderr_to_subscriber(pid)}

  defp add_bootstrap_subscriber(state, {pid, tag})
       when is_pid(pid) and is_reference(tag) do
    {:ok, state |> put_subscriber(pid, tag) |> maybe_replay_stderr_to_subscriber(pid)}
  end

  defp add_bootstrap_subscriber(_state, subscriber) do
    {:error, Error.invalid_options({:invalid_subscriber, subscriber})}
  end

  defp put_subscriber(state, pid, tag) do
    %{state | subscribers: SubscriberRegistry.put(state.subscribers, pid, tag)}
    |> cancel_headless_timer()
  end

  defp remove_subscriber(state, pid) do
    case SubscriberRegistry.remove(state.subscribers, pid) do
      {nil, _subscribers} ->
        state

      {_monitor_ref, subscribers} ->
        %{state | subscribers: subscribers}
        |> maybe_schedule_headless_timer()
    end
  end

  defp maybe_replay_stderr_to_subscriber(
         %{replay_stderr_on_subscribe?: true, stderr_buffer: stderr_buffer} = state,
         pid
       )
       when is_pid(pid) and is_binary(stderr_buffer) and stderr_buffer != "" do
    case Map.fetch(state.subscribers, pid) do
      {:ok, subscriber_info} ->
        SubscriberRegistry.dispatch(
          pid,
          subscriber_info,
          {:stderr, stderr_buffer},
          state.event_tag
        )

        state

      :error ->
        state
    end
  end

  defp maybe_replay_stderr_to_subscriber(state, _pid), do: state

  defp maybe_replay_buffered_events_to_subscriber(
         %{buffer_events_until_subscribe?: true, buffered_event_count: count} = state,
         pid,
         true
       )
       when count > 0 do
    case Map.fetch(state.subscribers, pid) do
      {:ok, subscriber_info} ->
        Enum.each(:queue.to_list(state.buffered_events), fn event ->
          SubscriberRegistry.dispatch(pid, subscriber_info, event, state.event_tag)
        end)

        %{state | buffered_events: :queue.new(), buffered_event_count: 0}

      :error ->
        state
    end
  end

  defp maybe_replay_buffered_events_to_subscriber(state, _pid, _first_subscriber?), do: state

  defp buffer_event(%{buffered_events: events, buffered_event_count: count} = state, event) do
    {events, count} =
      SubscriberRegistry.buffer_event(events, count, state.max_buffered_events, event)

    %{state | buffered_events: events, buffered_event_count: count}
  end

  defp handle_subscriber_down(ref, pid, state) do
    %{state | subscribers: SubscriberRegistry.handle_down(state.subscribers, ref, pid)}
    |> maybe_schedule_headless_timer()
  end

  defp flush_exit_mailbox(state, pid, os_pid) do
    receive do
      {:stdout, ^os_pid, chunk} ->
        state
        |> append_stdout_chunk(IO.iodata_to_binary(chunk))
        |> flush_exit_mailbox(pid, os_pid)

      {:stderr, ^os_pid, chunk} ->
        state
        |> append_stderr_chunk(IO.iodata_to_binary(chunk))
        |> flush_exit_mailbox(pid, os_pid)

      {:DOWN, ^os_pid, :process, ^pid, _reason} ->
        flush_exit_mailbox(state, pid, os_pid)
    after
      0 ->
        state
    end
  end

  defp maybe_schedule_headless_timer(%{headless_timer_ref: ref} = state) when not is_nil(ref),
    do: state

  defp maybe_schedule_headless_timer(%{subscribers: subscribers} = state)
       when map_size(subscribers) > 0,
       do: state

  defp maybe_schedule_headless_timer(%{headless_timeout_ms: :infinity} = state), do: state

  defp maybe_schedule_headless_timer(%{headless_timeout_ms: timeout_ms} = state)
       when is_integer(timeout_ms) and timeout_ms > 0 do
    timer_ref = Process.send_after(self(), :headless_timeout, timeout_ms)
    %{state | headless_timer_ref: timer_ref}
  end

  defp maybe_schedule_headless_timer(state), do: state

  defp cancel_headless_timer(%{headless_timer_ref: nil} = state), do: state

  defp cancel_headless_timer(state) do
    _ = Process.cancel_timer(state.headless_timer_ref, async: false, info: false)
    flush_headless_timeout_message()
    %{state | headless_timer_ref: nil}
  end

  defp flush_headless_timeout_message do
    receive do
      :headless_timeout -> :ok
    after
      0 -> :ok
    end
  end

  defp start_io_task(state, fun) when is_function(fun, 0) do
    TaskSupport.async_nolink(state.task_supervisor, fun)
  end

  defp append_stdout_chunk(%{stdout_mode: :raw} = state, data) when is_binary(data) do
    emit_event(state, {:data, data})
  end

  defp append_stdout_chunk(state, data) when is_binary(data) do
    append_stdout_data(state, data)
  end

  defp append_stderr_chunk(state, data) when is_binary(data) do
    stderr_buffer =
      Framing.append_stderr_buffer(state.stderr_buffer, data, state.max_stderr_buffer_size)

    {stderr_lines, stderr_framer} = Framing.push_stderr(state.stderr_framer, data)

    dispatch_stderr_callback(state.stderr_callback, stderr_lines)
    state = emit_event(state, {:stderr, data})

    %{state | stderr_buffer: stderr_buffer, stderr_framer: stderr_framer}
  end

  defp emit_event(%{subscribers: subscribers} = state, event) when map_size(subscribers) > 0 do
    SubscriberRegistry.send_event(subscribers, event, state.event_tag)
    state
  end

  defp emit_event(%{buffer_events_until_subscribe?: true} = state, event) do
    buffer_event(state, event)
  end

  defp emit_event(state, _event), do: state

  defp subscribe_with_tag(transport, pid, tag)
       when is_pid(transport) and is_pid(pid) and (is_pid(tag) or is_reference(tag)) do
    case safe_call(transport, {:subscribe, pid, tag}) do
      {:ok, result} -> result
      {:error, reason} -> transport_error(reason)
    end
  end

  defp append_stdout_data(%{overflowed?: true} = state, data) when is_binary(data) do
    case Framing.drop_until_next_newline(data) do
      :none ->
        state

      {:rest, rest} ->
        state
        |> Map.put(:overflowed?, false)
        |> Map.put(:stdout_framer, LineFraming.new())
        |> append_stdout_data(rest)
    end
  end

  defp append_stdout_data(%{fatal_stop_scheduled?: true} = state, _data), do: state

  defp append_stdout_data(%{long_line_spool: spool} = state, data)
       when is_map(spool) and is_binary(data) do
    append_chunked_long_line(state, data)
  end

  defp append_stdout_data(state, data) when is_binary(data) do
    {lines, stdout_framer} = Framing.push_stdout(state.stdout_framer, data)

    pending_lines = Framing.enqueue_lines(state.pending_lines, lines)

    state = %{
      state
      | pending_lines: pending_lines,
        stdout_framer: stdout_framer,
        overflowed?: false
    }

    cond do
      byte_size(stdout_framer.buffer) <= state.max_buffer_size ->
        state

      state.oversize_line_mode == :chunk_then_fail ->
        promote_long_line(state)

      true ->
        fatal_buffer_overflow(
          state,
          byte_size(stdout_framer.buffer),
          state.max_recoverable_line_bytes || state.max_buffer_size,
          Framing.preview(stdout_framer.buffer)
        )
    end
  end

  defp drain_stdout_lines(state, 0), do: state

  defp drain_stdout_lines(state, remaining) when is_integer(remaining) and remaining > 0 do
    case :queue.out(state.pending_lines) do
      {:empty, _queue} ->
        state

      {{:value, line}, queue} ->
        state = %{state | pending_lines: queue}

        state = maybe_emit_stdout_line(state, line)

        drain_stdout_lines(state, remaining - 1)
    end
  end

  defp maybe_schedule_drain(%{drain_scheduled?: true} = state), do: state

  defp maybe_schedule_drain(state) do
    if :queue.is_empty(state.pending_lines) do
      state
    else
      Kernel.send(self(), :drain_stdout)
      %{state | drain_scheduled?: true}
    end
  end

  defp flush_stdout_fragment(%{stdout_framer: %LineFraming{buffer: ""}} = state) do
    flush_chunked_long_line_fragment(%{state | drain_scheduled?: false})
  end

  defp flush_stdout_fragment(state) do
    {[line], stdout_framer} = Framing.flush_stdout(state.stdout_framer)

    state = %{
      state
      | stdout_framer: stdout_framer,
        overflowed?: false,
        drain_scheduled?: false
    }

    if line == "" do
      flush_chunked_long_line_fragment(state)
    else
      state
      |> maybe_emit_stdout_line(line)
      |> flush_chunked_long_line_fragment()
    end
  end

  defp flush_stderr_fragment(%{stderr_framer: %LineFraming{buffer: ""}} = state), do: state

  defp flush_stderr_fragment(state) do
    {lines, stderr_framer} = Framing.flush_stderr(state.stderr_framer)
    dispatch_stderr_callback(state.stderr_callback, lines)
    %{state | stderr_framer: stderr_framer}
  end

  defp cancel_finalize_timer(%{finalize_timer_ref: nil} = state), do: state

  defp cancel_finalize_timer(state) do
    _ = Process.cancel_timer(state.finalize_timer_ref, async: false, info: false)
    flush_finalize_message(state.subprocess)
    %{state | finalize_timer_ref: nil}
  end

  defp flush_finalize_message({pid, os_pid}) do
    receive do
      {:finalize_exit, ^os_pid, ^pid, _reason} -> :ok
    after
      0 -> :ok
    end
  end

  defp flush_finalize_message(_other), do: :ok

  defp dispatch_stderr_callback(callback, lines)
       when is_function(callback, 1) and is_list(lines) do
    Enum.each(lines, callback)
  end

  defp dispatch_stderr_callback(_callback, _lines), do: :ok

  defp force_stop_subprocess(%{subprocess: {pid, os_pid}} = state) do
    SignalControl.force_stop({pid, os_pid}, state.os)
    %{state | subprocess: nil, status: :disconnected}
  end

  defp force_stop_subprocess(state), do: state

  defp transport_error({:transport, %Error{}} = error), do: {:error, error}
  defp transport_error(%Error{} = error), do: {:error, {:transport, error}}
  defp transport_error(reason), do: {:error, {:transport, Error.transport_error(reason)}}

  defp maybe_stop_after_fatal(%{fatal_stop_scheduled?: true} = state), do: {:stop, :normal, state}
  defp maybe_stop_after_fatal(state), do: {:noreply, state}

  defp maybe_emit_stdout_line(state, line) when is_binary(line) do
    if byte_size(line) > state.max_recoverable_line_bytes do
      fatal_buffer_overflow(
        state,
        byte_size(line),
        state.max_recoverable_line_bytes,
        Framing.preview(line),
        %{line_recovery_attempted?: false, bytes_preserved: 0, chunk_count: 0}
      )
    else
      emit_event(state, {:message, line})
    end
  end

  defp promote_long_line(%{stdout_framer: %LineFraming{buffer: buffer}} = state)
       when is_binary(buffer) do
    case open_long_line_spool() do
      {:ok, spool} ->
        case write_long_line_data(spool, buffer, state) do
          {:ok, spool} ->
            %{state | stdout_framer: LineFraming.new(), long_line_spool: spool}

          {:error, {:recoverable_ceiling_exceeded, actual_size, spool}} ->
            fatal_buffer_overflow(
              %{state | long_line_spool: spool},
              actual_size,
              state.max_recoverable_line_bytes,
              Framing.preview(buffer),
              long_line_context(spool, state, line_recovery_attempted?: true)
            )

          {:error, {:spool_write_failed, reason, spool}} ->
            fatal_buffer_overflow(
              %{state | long_line_spool: spool},
              spool.bytes,
              state.max_recoverable_line_bytes,
              Framing.preview(buffer),
              long_line_context(spool, state,
                line_recovery_attempted?: true,
                failure: {:spool_write_failed, reason}
              )
            )
        end

      {:error, reason} ->
        fatal_buffer_overflow(
          state,
          byte_size(buffer),
          state.max_recoverable_line_bytes,
          Framing.preview(buffer),
          %{line_recovery_attempted?: true, failure: {:spool_open_failed, reason}}
        )
    end
  end

  defp append_chunked_long_line(%{long_line_spool: spool} = state, data) do
    data = if spool.pending_cr?, do: "\r" <> data, else: data
    state = %{state | long_line_spool: %{spool | pending_cr?: false}}

    case Framing.split_long_line_data(data) do
      {:incomplete, payload, pending_cr?} ->
        handle_incomplete_chunked_long_line(state, payload, pending_cr?)

      {:complete, payload, rest} ->
        handle_complete_chunked_long_line(state, payload, rest)
    end
  end

  defp handle_incomplete_chunked_long_line(
         %{long_line_spool: spool} = state,
         payload,
         pending_cr?
       ) do
    case write_long_line_data(spool, payload, state) do
      {:ok, spool} ->
        %{state | long_line_spool: %{spool | pending_cr?: pending_cr?}}

      {:error, {:recoverable_ceiling_exceeded, actual_size, spool}} ->
        long_line_ceiling_exceeded(state, spool, actual_size, payload)

      {:error, {:spool_write_failed, reason, spool}} ->
        long_line_spool_write_failed(state, spool, payload, reason)
    end
  end

  defp handle_complete_chunked_long_line(%{long_line_spool: spool} = state, payload, rest) do
    case write_long_line_data(spool, payload, state) do
      {:ok, spool} ->
        finish_chunked_long_line(state, spool, payload, rest)

      {:error, {:recoverable_ceiling_exceeded, actual_size, spool}} ->
        long_line_ceiling_exceeded(state, spool, actual_size, payload)

      {:error, {:spool_write_failed, reason, spool}} ->
        long_line_spool_write_failed(state, spool, payload, reason)
    end
  end

  defp finish_chunked_long_line(state, spool, payload, rest) do
    case finalize_long_line_spool(spool) do
      {:ok, line} ->
        state
        |> Map.put(:long_line_spool, nil)
        |> maybe_emit_stdout_line(line)
        |> append_stdout_data(rest)

      {:error, reason} ->
        long_line_spool_read_failed(state, spool, payload, reason)
    end
  end

  defp long_line_ceiling_exceeded(state, spool, actual_size, payload) do
    fatal_buffer_overflow(
      %{state | long_line_spool: spool},
      actual_size,
      state.max_recoverable_line_bytes,
      Framing.preview(payload),
      long_line_context(spool, state, line_recovery_attempted?: true)
    )
  end

  defp long_line_spool_write_failed(state, spool, payload, reason) do
    fatal_buffer_overflow(
      %{state | long_line_spool: spool},
      max(spool.bytes, 1),
      state.max_recoverable_line_bytes,
      Framing.preview(payload),
      long_line_context(spool, state,
        line_recovery_attempted?: true,
        failure: {:spool_write_failed, reason}
      )
    )
  end

  defp long_line_spool_read_failed(state, spool, payload, reason) do
    fatal_buffer_overflow(
      %{state | long_line_spool: spool},
      spool.bytes,
      state.max_recoverable_line_bytes,
      Framing.preview(payload),
      long_line_context(spool, state,
        line_recovery_attempted?: true,
        failure: {:spool_read_failed, reason}
      )
    )
  end

  defp flush_chunked_long_line_fragment(%{long_line_spool: nil} = state), do: state

  defp flush_chunked_long_line_fragment(%{long_line_spool: spool} = state) do
    case finalize_long_line_spool(spool) do
      {:ok, line} ->
        state
        |> Map.put(:long_line_spool, nil)
        |> maybe_emit_stdout_line(line)

      {:error, reason} ->
        fatal_buffer_overflow(
          %{state | long_line_spool: spool},
          spool.bytes,
          state.max_recoverable_line_bytes,
          Framing.preview(spool.preview),
          long_line_context(spool, state,
            line_recovery_attempted?: true,
            failure: {:spool_read_failed, reason}
          )
        )
    end
  end

  defp fatal_buffer_overflow(state, actual_size, max_size, preview, extra_context \\ %{}) do
    error =
      Error.buffer_overflow(
        actual_size,
        max_size,
        preview,
        long_line_context(state.long_line_spool, state, extra_context)
      )

    state
    |> emit_event({:error, error})
    |> emit_event({:exit, ProcessExit.from_reason(error.reason, stderr: state.stderr_buffer)})
    |> cleanup_long_line_spool()
    |> force_stop_subprocess()
    |> Map.put(:status, :error)
    |> Map.put(:fatal_stop_scheduled?, true)
    |> Map.put(:stdout_framer, LineFraming.new())
    |> Map.put(:pending_lines, :queue.new())
    |> Map.put(:drain_scheduled?, false)
    |> Map.put(:overflowed?, false)
  end

  defp long_line_context(spool, state, extra) when is_list(extra) do
    long_line_context(spool, state, Enum.into(extra, %{}))
  end

  defp long_line_context(spool, state, extra) when is_map(extra) do
    %{
      mode: state.oversize_line_mode,
      buffer_overflow_mode: state.buffer_overflow_mode,
      line_recovery_attempted?: not is_nil(spool),
      max_recoverable_line_bytes: state.max_recoverable_line_bytes,
      oversize_line_chunk_bytes: state.oversize_line_chunk_bytes,
      bytes_preserved: long_line_bytes_preserved(spool),
      chunk_count: long_line_chunk_count(spool),
      first_fatal?: true
    }
    |> Map.merge(extra)
  end

  defp long_line_bytes_preserved(%{bytes: bytes}) when is_integer(bytes), do: bytes
  defp long_line_bytes_preserved(_spool), do: 0

  defp long_line_chunk_count(%{chunk_count: count}) when is_integer(count), do: count
  defp long_line_chunk_count(_spool), do: 0

  defp open_long_line_spool do
    path =
      Path.join(
        System.tmp_dir!(),
        "external_runtime_transport_long_line_#{System.unique_integer([:positive])}.tmp"
      )

    case File.open(path, [:write, :binary]) do
      {:ok, io} ->
        {:ok, %{path: path, io: io, bytes: 0, chunk_count: 0, preview: "", pending_cr?: false}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_long_line_data(spool, "", _state), do: {:ok, spool}

  defp write_long_line_data(spool, data, state) when is_binary(data) do
    do_write_long_line_data(spool, data, state.oversize_line_chunk_bytes, state)
  end

  defp do_write_long_line_data(spool, "", _chunk_bytes, _state), do: {:ok, spool}

  defp do_write_long_line_data(spool, data, chunk_bytes, state) do
    size = min(byte_size(data), chunk_bytes)
    chunk = binary_part(data, 0, size)
    rest = binary_part(data, size, byte_size(data) - size)
    next_size = spool.bytes + byte_size(chunk)

    if next_size > state.max_recoverable_line_bytes do
      {:error, {:recoverable_ceiling_exceeded, next_size, spool}}
    else
      case :file.write(spool.io, chunk) do
        :ok ->
          spool =
            %{
              spool
              | bytes: next_size,
                chunk_count: spool.chunk_count + 1,
                preview: Framing.extend_preview(spool.preview, chunk)
            }

          do_write_long_line_data(spool, rest, chunk_bytes, state)

        {:error, reason} ->
          {:error, {:spool_write_failed, reason, spool}}
      end
    end
  end

  defp finalize_long_line_spool(spool) do
    :ok = File.close(spool.io)

    case File.read(spool.path) do
      {:ok, line} ->
        _ = File.rm(spool.path)
        {:ok, line}

      {:error, reason} ->
        _ = File.rm(spool.path)
        {:error, reason}
    end
  rescue
    error ->
      _ = File.rm(spool.path)
      {:error, error}
  end

  defp cleanup_long_line_spool(%{long_line_spool: nil} = state), do: state

  defp cleanup_long_line_spool(%{long_line_spool: spool} = state) when is_map(spool) do
    _ = maybe_close_spool_io(spool)
    _ = File.rm(spool.path)
    %{state | long_line_spool: nil}
  end

  defp maybe_close_spool_io(%{io: io}) when not is_nil(io) do
    File.close(io)
  rescue
    _ -> :ok
  end

  defp maybe_close_spool_io(_spool), do: :ok
end
