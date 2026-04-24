defmodule ExecutionPlane.OperatorTerminal do
  @moduledoc """
  Generic operator-terminal ingress owned by the Execution Plane operator lane.

  This family is intentionally distinct from workload execution surfaces such
  as `:local_subprocess` and `:ssh_exec`. It owns the transport/runtime needed
  to host operator-facing TUIs, while the product TUI module itself stays above
  Execution Plane.
  """

  alias ExecutionPlane.OperatorTerminal.{Info, Server, Surface}

  @spec start_link(keyword()) :: DynamicSupervisor.on_start_child()
  def start_link(opts) when is_list(opts) do
    with {:ok, normalized} <- normalize_start_opts(opts) do
      DynamicSupervisor.start_child(
        ExecutionPlane.OperatorTerminal.Supervisor,
        {Server, normalized}
      )
    end
  end

  @spec start(keyword()) :: GenServer.on_start()
  def start(opts) when is_list(opts) do
    with {:ok, normalized} <- normalize_start_opts(opts) do
      Server.start_link(normalized)
    end
  end

  @spec info(GenServer.server() | String.t()) :: Info.t() | nil
  def info(target \\ nil)

  def info(nil) do
    case list() do
      [info] -> info
      _other -> nil
    end
  end

  def info(target) when is_pid(target) or is_binary(target) do
    case resolve_server(target) do
      nil -> nil
      server -> safe_info(server)
    end
  end

  @spec list() :: [Info.t()]
  def list do
    ExecutionPlane.OperatorTerminal.Registry
    |> Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.sort_by(fn {terminal_id, _pid} -> terminal_id end)
    |> Enum.map(fn {_terminal_id, pid} -> safe_info(pid) end)
    |> Enum.reject(&is_nil/1)
  end

  @spec stop(GenServer.server() | String.t()) :: :ok | {:error, :not_found}
  def stop(target) when is_pid(target) or is_binary(target) do
    case resolve_server(target) do
      nil ->
        {:error, :not_found}

      server ->
        safe_stop(server)
    end
  end

  @spec port(GenServer.server() | String.t()) :: non_neg_integer() | nil
  def port(target) when is_pid(target) or is_binary(target) do
    case info(target) do
      %Info{adapter_metadata: %{port: port}} when is_integer(port) -> port
      _other -> nil
    end
  end

  @spec supported_surface_kinds() :: [Surface.surface_kind(), ...]
  def supported_surface_kinds, do: Surface.supported_surface_kinds()

  defp normalize_start_opts(opts) do
    with {:ok, mod} <- fetch_mod(opts),
         {:ok, %Surface{} = surface} <- Surface.new(opts) do
      {:ok,
       opts
       |> Keyword.put(:mod, mod)
       |> Keyword.put(:surface, surface)
       |> Keyword.put(:terminal_id, surface.surface_ref || generated_terminal_id())}
    end
  end

  defp fetch_mod(opts) do
    case Keyword.get(opts, :mod) do
      mod when is_atom(mod) -> {:ok, mod}
      other -> {:error, {:invalid_operator_terminal_mod, other}}
    end
  end

  defp resolve_server(pid) when is_pid(pid), do: pid

  defp resolve_server(terminal_id) when is_binary(terminal_id) do
    case Registry.lookup(ExecutionPlane.OperatorTerminal.Registry, terminal_id) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end

  defp generated_terminal_id do
    "operator_terminal-#{System.unique_integer([:positive])}"
  end

  defp safe_info(server) do
    GenServer.call(server, :info)
  catch
    :exit, _reason -> nil
  end

  defp safe_stop(pid) when is_pid(pid) do
    if Process.alive?(pid), do: stop_live_server(pid), else: {:error, :not_found}
  end

  defp stop_live_server(server) do
    GenServer.stop(server, :normal)
    :ok
  catch
    :exit, _reason -> {:error, :not_found}
  end
end
