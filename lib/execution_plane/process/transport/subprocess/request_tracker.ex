defmodule ExecutionPlane.Process.Transport.Subprocess.RequestTracker do
  @moduledoc false

  @doc false
  def put(state, ref, from) when is_reference(ref) do
    %{state | pending_calls: Map.put(state.pending_calls, ref, from)}
  end

  @doc false
  def pop(state, ref) when is_reference(ref) do
    {from, pending_calls} = Map.pop(state.pending_calls, ref)
    {from, %{state | pending_calls: pending_calls}}
  end

  @doc false
  def cleanup(pending_calls, reply_fun)
      when is_map(pending_calls) and is_function(reply_fun, 1) do
    Enum.each(pending_calls, fn {ref, from} ->
      Process.demonitor(ref, [:flush])
      GenServer.reply(from, reply_fun.(:transport_stopped))
    end)
  end
end
