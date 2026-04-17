defmodule ExecutionPlane.OperatorTerminal.Server do
  @moduledoc false

  use GenServer

  alias ExecutionPlane.OperatorTerminal.{Info, Surface}
  alias ExRatatui.SSH.Daemon

  @type state :: %{
          terminal_id: String.t(),
          mod: module(),
          app_opts: keyword(),
          surface: Surface.t(),
          backend_pid: pid(),
          backend_ref: reference(),
          adapter_metadata: map()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    terminal_id = Keyword.fetch!(opts, :terminal_id)

    GenServer.start_link(
      __MODULE__,
      opts,
      name: {:via, Registry, {ExecutionPlane.OperatorTerminal.Registry, terminal_id}}
    )
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    mod = Keyword.fetch!(opts, :mod)
    surface = Keyword.fetch!(opts, :surface)
    terminal_id = Keyword.fetch!(opts, :terminal_id)
    app_opts = Keyword.get(opts, :app_opts, [])

    with {:ok, backend_pid} <- start_backend(mod, surface, app_opts) do
      {:ok,
       %{
         terminal_id: terminal_id,
         mod: mod,
         app_opts: app_opts,
         surface: surface,
         backend_pid: backend_pid,
         backend_ref: Process.monitor(backend_pid),
         adapter_metadata: adapter_metadata(surface, backend_pid)
       }}
    end
  end

  @impl true
  def handle_call(:info, _from, state) do
    {:reply, info(state, :running), state}
  end

  @impl true
  def handle_info(
        {:DOWN, ref, :process, backend_pid, _reason},
        %{backend_ref: ref, backend_pid: backend_pid} = state
      ) do
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, backend_pid, _reason}, %{backend_pid: backend_pid} = state) do
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, %{backend_pid: backend_pid}) when is_pid(backend_pid) do
    if Process.alive?(backend_pid) do
      Process.exit(backend_pid, :normal)
    end

    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp start_backend(mod, %Surface{} = surface, app_opts) do
    startup_opts =
      app_opts
      |> Keyword.merge(surface.transport_options)
      |> Keyword.put(:name, nil)
      |> Keyword.put(:transport, transport_mode(surface.surface_kind))

    mod.start_link(startup_opts)
  rescue
    error in [ArgumentError, UndefinedFunctionError] ->
      {:error, {:operator_terminal_start_failed, Exception.message(error)}}
  end

  defp transport_mode(:local_terminal), do: :local
  defp transport_mode(:ssh_terminal), do: :ssh
  defp transport_mode(:distributed_terminal), do: :distributed

  defp adapter_metadata(%Surface{surface_kind: :local_terminal}, _backend_pid), do: %{}

  defp adapter_metadata(%Surface{surface_kind: :ssh_terminal}, backend_pid) do
    %{port: Daemon.port(backend_pid)}
  end

  defp adapter_metadata(
         %Surface{surface_kind: :distributed_terminal, transport_options: transport_options},
         _backend_pid
       ) do
    case Keyword.get(transport_options, :name) do
      nil -> %{}
      name -> %{listener: name}
    end
  end

  defp info(state, status) do
    %Info{
      terminal_id: state.terminal_id,
      mod: state.mod,
      surface_kind: state.surface.surface_kind,
      surface_ref: state.surface.surface_ref,
      boundary_class: state.surface.boundary_class,
      observability: state.surface.observability,
      transport_options: Map.new(state.surface.transport_options),
      adapter_metadata: state.adapter_metadata,
      status: status
    }
  end
end
