defmodule ExecutionPlane.Process.Transport.GuestBridge.RequestTracker do
  @moduledoc false

  @doc false
  def next(state, from) do
    request_seq = state.request_seq + 1
    request_id = Integer.to_string(request_seq)

    state = %{
      state
      | request_seq: request_seq,
        pending_requests: Map.put(state.pending_requests, request_id, from)
    }

    {request_id, state}
  end

  @doc false
  def pop(state, request_id) when is_binary(request_id) do
    {from, pending_requests} = Map.pop(state.pending_requests, request_id)
    {from, %{state | pending_requests: pending_requests}}
  end

  @doc false
  def cleanup(pending_requests, reply_fun)
      when is_map(pending_requests) and is_function(reply_fun, 0) do
    Enum.each(pending_requests, fn {_id, from} ->
      GenServer.reply(from, reply_fun.())
    end)
  end
end
