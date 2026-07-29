defmodule ExecutionPlane.Node.DistributedClient do
  @moduledoc """
  Runtime Client for a trusted local or distributed Node Server target.

  The configured server may be a pid, registered atom, or
  `{registered_name_atom, node_atom}`. Strings are rejected so untrusted input
  is never converted into a node or registered-name atom.
  """

  @behaviour ExecutionPlane.Runtime.Client

  alias ExecutionPlane.Node.Server

  @default_timeout 5_000

  @impl true
  def start(request, opts), do: call(opts, &Server.start_execution(&1, request, &2))

  @impl true
  def subscribe(ref, subscriber, opts),
    do: call(opts, &Server.subscribe_execution(&1, ref, subscriber, &2))

  @impl true
  def send_input(ref, input, opts),
    do: call(opts, &Server.send_execution_input(&1, ref, input, &2))

  @impl true
  def end_input(ref, opts), do: call(opts, &Server.end_execution_input(&1, ref, &2))

  @impl true
  def status(ref, opts), do: call(opts, &Server.execution_status(&1, ref, &2))

  @impl true
  def cancel(ref, opts), do: call(opts, &Server.cancel_execution(&1, ref, &2))

  defp call(opts, callback) when is_list(opts) do
    with {:ok, server} <- trusted_server(Keyword.get(opts, :server)),
         {:ok, timeout} <- timeout(opts) do
      callback.(server, Keyword.put(opts, :timeout, timeout))
    end
  catch
    :exit, {:timeout, _details} -> {:error, :runtime_client_timeout}
    :exit, {:noproc, _details} -> {:error, :runtime_node_unavailable}
    :exit, {:nodedown, _node} -> {:error, :runtime_node_unavailable}
    :exit, {{:nodedown, _node}, _details} -> {:error, :runtime_node_unavailable}
  end

  defp call(_opts, _callback), do: {:error, :invalid_runtime_client_options}

  defp trusted_server(server) when is_pid(server) or is_atom(server), do: {:ok, server}

  defp trusted_server({name, node}) when is_atom(name) and is_atom(node),
    do: {:ok, {name, node}}

  defp trusted_server(_server), do: {:error, :invalid_runtime_server}

  defp timeout(opts) do
    case Keyword.get(opts, :timeout, @default_timeout) do
      timeout when is_integer(timeout) and timeout > 0 -> {:ok, timeout}
      _other -> {:error, :invalid_runtime_timeout}
    end
  end
end
