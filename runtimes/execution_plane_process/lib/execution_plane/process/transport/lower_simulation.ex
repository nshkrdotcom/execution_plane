defmodule ExecutionPlane.Process.Transport.LowerSimulation do
  @moduledoc """
  Execution Plane-owned process transport simulation surface.

  The adapter replays configured stdout/stderr/exit frames through the normal
  process transport contract. It never spawns a process and is intended to be
  selected by higher-layer configuration, not by public request keywords.
  """

  use GenServer

  alias ExecutionPlane.{Command, ProcessExit}

  alias ExecutionPlane.Process.Transport.{
    Delivery,
    Error,
    Info,
    RunResult,
    Surface.Adapter,
    Surface.Capabilities
  }

  @behaviour Adapter

  @surface_kind :lower_simulation
  @event_tag :execution_plane_process

  defstruct [
    :command,
    :delivery,
    :event_tag,
    :exit,
    :scenario_ref,
    :surface_kind,
    :target_id,
    :lease_ref,
    :surface_ref,
    :boundary_class,
    :observability,
    :adapter_capabilities,
    :effective_capabilities,
    stdout_frames: [],
    stderr_frames: [],
    subscribers: %{},
    status: :connected,
    played?: false,
    received_input: []
  ]

  @impl Adapter
  def surface_kind, do: @surface_kind

  @impl Adapter
  def capabilities do
    Capabilities.new!(
      remote?: false,
      startup_kind: :attach,
      path_semantics: :local,
      supports_run?: true,
      supports_streaming_stdio?: true,
      supports_pty?: false,
      supports_user?: true,
      supports_env?: true,
      supports_cwd?: true,
      interrupt_kind: :none
    )
  end

  @impl Adapter
  def normalize_transport_options(options) when is_list(options) do
    if Keyword.keyword?(options) do
      with {:ok, _scenario} <- validate_options(options) do
        {:ok, options}
      else
        {:error, reason} -> {:error, {:invalid_transport_options, reason}}
      end
    else
      {:error, {:invalid_transport_options, options}}
    end
  end

  def normalize_transport_options(options) when is_map(options) do
    options
    |> Enum.map(fn {key, value} -> {normalize_key(key), value} end)
    |> normalize_transport_options()
  rescue
    ArgumentError -> {:error, {:invalid_transport_options, options}}
  end

  def normalize_transport_options(options), do: {:error, {:invalid_transport_options, options}}

  @spec start(keyword()) :: {:ok, pid()} | {:error, {:transport, Error.t()}}
  def start(opts) when is_list(opts), do: do_start(:start, opts)

  @spec start_link(keyword()) :: {:ok, pid()} | {:error, {:transport, Error.t()}}
  def start_link(opts) when is_list(opts), do: do_start(:start_link, opts)

  @spec run(Command.t(), keyword()) :: {:ok, RunResult.t()} | {:error, {:transport, Error.t()}}
  def run(%Command{} = command, opts) when is_list(opts) do
    with {:ok, scenario} <- scenario(opts) do
      stdout = IO.iodata_to_binary(scenario.stdout_frames)
      stderr = IO.iodata_to_binary(scenario.stderr_frames)

      {:ok,
       %RunResult{
         invocation: command,
         stdout: stdout,
         stderr: stderr,
         output: output(stdout, stderr, Keyword.get(opts, :stderr, :separate)),
         exit: scenario.exit,
         stderr_mode: Keyword.get(opts, :stderr, :separate)
       }}
    end
  end

  @impl GenServer
  def init(opts) do
    with {:ok, scenario} <- scenario(opts) do
      delivery = Delivery.new(Keyword.get(opts, :event_tag, @event_tag))

      state =
        %__MODULE__{
          command: Keyword.get(opts, :command),
          delivery: delivery,
          event_tag: delivery.tagged_event_tag,
          exit: scenario.exit,
          scenario_ref: scenario.scenario_ref,
          surface_kind: Keyword.get(opts, :surface_kind, @surface_kind),
          target_id: Keyword.get(opts, :target_id),
          lease_ref: Keyword.get(opts, :lease_ref),
          surface_ref: Keyword.get(opts, :surface_ref),
          boundary_class: Keyword.get(opts, :boundary_class),
          observability: Keyword.get(opts, :observability, %{}),
          adapter_capabilities: Keyword.get(opts, :adapter_capabilities, capabilities()),
          effective_capabilities: Keyword.get(opts, :effective_capabilities, capabilities()),
          stdout_frames: scenario.stdout_frames,
          stderr_frames: scenario.stderr_frames
        }
        |> maybe_put_subscriber(Keyword.get(opts, :subscriber))

      send(self(), :playback)
      {:ok, state}
    else
      {:error, {:transport, %Error{}} = error} -> {:stop, error}
    end
  end

  @impl GenServer
  def handle_call({:send, input}, _from, state) do
    {:reply, :ok, %{state | received_input: [input | state.received_input]}}
  end

  def handle_call({:subscribe, pid, tag}, _from, state) do
    state = put_subscriber(state, pid, tag)

    if state.played? do
      replay_to(pid, tag, state)
    end

    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, pid}, _from, state) do
    {:reply, :ok, %{state | subscribers: Map.delete(state.subscribers, pid)}}
  end

  def handle_call(:interrupt, _from, state), do: {:reply, :ok, state}
  def handle_call(:end_input, _from, state), do: {:reply, :ok, state}

  def handle_call(:stderr, _from, state),
    do: {:reply, IO.iodata_to_binary(state.stderr_frames), state}

  def handle_call(:status, _from, state), do: {:reply, state.status, state}
  def handle_call(:info, _from, state), do: {:reply, info(state), state}

  @impl GenServer
  def handle_info(:playback, state) do
    Enum.each(state.subscribers, fn {pid, tag} -> replay_to(pid, tag, state) end)
    {:noreply, %{state | played?: true}}
  end

  defp do_start(fun, opts) do
    case apply(GenServer, fun, [__MODULE__, opts]) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:transport, %Error{}} = error} -> {:error, error}
      {:error, reason} -> transport_error(Error.startup_failed(reason))
    end
  end

  defp scenario(opts) do
    opts
    |> Keyword.get(:transport_options, [])
    |> validate_options()
    |> case do
      {:ok, scenario} -> {:ok, scenario}
      {:error, reason} -> invalid_options(reason)
    end
  end

  defp validate_options(options) when is_list(options) do
    if Keyword.keyword?(options) do
      with {:ok, scenario_ref} <- required_string(options, :scenario_ref),
           {:ok, stdout_frames} <- frames(options, :stdout, :stdout_frames),
           {:ok, stderr_frames} <- frames(options, :stderr, :stderr_frames),
           {:ok, exit} <- exit(options, stderr_frames) do
        {:ok,
         %{
           scenario_ref: scenario_ref,
           stdout_frames: stdout_frames,
           stderr_frames: stderr_frames,
           exit: exit
         }}
      end
    else
      {:error, {:invalid_transport_options, options}}
    end
  end

  defp validate_options(options), do: {:error, {:invalid_transport_options, options}}

  defp required_string(options, key) do
    case Keyword.get(options, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      other -> {:error, {:missing_required_option, key, other}}
    end
  end

  defp frames(options, scalar_key, list_key) do
    case {Keyword.get(options, list_key), Keyword.get(options, scalar_key)} do
      {nil, nil} -> {:ok, []}
      {nil, value} when is_binary(value) -> {:ok, [value]}
      {values, _value} when is_list(values) -> validate_frame_list(values, list_key)
      {values, value} -> {:error, {:invalid_frames, list_key, values || value}}
    end
  end

  defp validate_frame_list(values, _key) do
    if Enum.all?(values, &is_binary/1) do
      {:ok, values}
    else
      {:error, {:invalid_frames, values}}
    end
  end

  defp exit(options, stderr_frames) do
    case Keyword.get(options, :exit, Keyword.get(options, :exit_code, 0)) do
      %ProcessExit{} = exit ->
        {:ok, exit}

      code when is_integer(code) ->
        {:ok, ProcessExit.from_reason(code, stderr: IO.iodata_to_binary(stderr_frames))}

      :normal ->
        {:ok, ProcessExit.from_reason(:normal, stderr: IO.iodata_to_binary(stderr_frames))}

      other ->
        {:error, {:invalid_exit, other}}
    end
  end

  defp output(stdout, _stderr, :separate), do: stdout
  defp output(stdout, stderr, :stdout), do: stdout <> stderr
  defp output(stdout, _stderr, _mode), do: stdout

  defp maybe_put_subscriber(state, nil), do: state

  defp maybe_put_subscriber(state, {pid, tag}) when is_pid(pid),
    do: put_subscriber(state, pid, tag)

  defp maybe_put_subscriber(state, pid) when is_pid(pid), do: put_subscriber(state, pid, pid)
  defp maybe_put_subscriber(state, _other), do: state

  defp put_subscriber(state, pid, tag) when is_pid(pid) do
    %{state | subscribers: Map.put(state.subscribers, pid, tag)}
  end

  defp replay_to(pid, tag, state) do
    Enum.each(state.stdout_frames, fn frame ->
      send(pid, {state.event_tag, tag, {:message, frame}})
    end)

    Enum.each(state.stderr_frames, fn frame ->
      send(pid, {state.event_tag, tag, {:stderr, frame}})
    end)

    send(pid, {state.event_tag, tag, {:exit, state.exit}})
  end

  defp info(state) do
    %Info{
      invocation: state.command,
      pid: self(),
      os_pid: nil,
      surface_kind: state.surface_kind,
      target_id: state.target_id,
      lease_ref: state.lease_ref,
      surface_ref: state.surface_ref,
      boundary_class: state.boundary_class,
      observability: state.observability,
      adapter_capabilities: state.adapter_capabilities,
      effective_capabilities: state.effective_capabilities,
      status: state.status,
      stdout_mode: :line,
      stdin_mode: :line,
      pty?: false,
      interrupt_mode: :signal,
      stderr: IO.iodata_to_binary(state.stderr_frames),
      delivery: state.delivery,
      adapter_metadata: %{
        lower_simulation?: true,
        scenario_ref: state.scenario_ref,
        side_effect_policy: "deny_process_spawn",
        side_effect_result: "not_attempted"
      }
    }
  end

  defp normalize_key(key) when is_atom(key), do: key

  defp normalize_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  end

  defp invalid_options(reason) do
    transport_error(Error.invalid_options(reason))
  end

  defp transport_error(%Error{} = error), do: {:error, {:transport, error}}
end
