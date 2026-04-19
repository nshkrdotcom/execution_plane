defmodule ExecutionPlane.SSE do
  @moduledoc """
  Execution Plane-owned SSE framing and stream lifecycle helper.

  Semantic families consume parsed SSE events plus the original raw chunk, while
  the lower HTTP stream worker and parser buffer stay below them.
  """

  @default_receive_timeout 30_000

  @type stream_item ::
          {:status, non_neg_integer()}
          | {:headers, list()}
          | {:sse, binary(), [map()]}
          | {:transport_error, term()}
          | :transport_timeout

  @spec parse(binary()) :: {[map()], binary()}
  def parse(buffer) when is_binary(buffer) do
    ServerSentEvents.parse(buffer)
  end

  @spec stream(Finch.Request.t(), atom(), keyword()) :: Enumerable.t()
  def stream(%Finch.Request{} = request, finch_name, opts \\ [])
      when is_atom(finch_name) and is_list(opts) do
    receive_timeout = Keyword.get(opts, :receive_timeout, @default_receive_timeout)

    Stream.resource(
      fn -> start_worker(request, finch_name, receive_timeout) end,
      &next_item/1,
      &cleanup/1
    )
  end

  defp start_worker(request, finch_name, receive_timeout) do
    ref = make_ref()
    parent = self()

    {worker_pid, worker_monitor_ref} =
      spawn_monitor(fn -> run_stream(parent, ref, request, finch_name) end)

    %{
      buffer: "",
      done?: false,
      finch_name: finch_name,
      receive_timeout: receive_timeout,
      ref: ref,
      worker_monitor_ref: worker_monitor_ref,
      worker_pid: worker_pid
    }
  end

  defp run_stream(parent, ref, request, finch_name) do
    result =
      Finch.stream(request, finch_name, nil, fn
        {:status, status}, acc ->
          send(parent, {ref, :status, status})
          acc

        {:headers, headers}, acc ->
          send(parent, {ref, :headers, headers})
          acc

        {:data, data}, acc ->
          send(parent, {ref, :data, data})
          acc

        _other, acc ->
          acc
      end)

    case result do
      {:ok, _acc} ->
        send(parent, {ref, :done})

      {:error, reason, _acc} ->
        send(parent, {ref, :transport_error, {:stream_failed, reason}})
        send(parent, {ref, :done})
    end
  rescue
    exception ->
      send(parent, {ref, :transport_error, {:stream_exception, exception}})
      send(parent, {ref, :done})
  catch
    kind, reason ->
      send(parent, {ref, :transport_error, {:stream_exit, {kind, reason}}})
      send(parent, {ref, :done})
  end

  defp next_item(%{done?: true} = state), do: {:halt, state}

  defp next_item(state) do
    receive do
      {ref, :status, status} when ref == state.ref ->
        {[{:status, status}], state}

      {ref, :headers, headers} when ref == state.ref ->
        {[{:headers, headers}], state}

      {ref, :data, data} when ref == state.ref ->
        {events, remaining} = parse(state.buffer <> data)
        {[{:sse, data, events}], %{state | buffer: remaining}}

      {ref, :transport_error, reason} when ref == state.ref ->
        {[{:transport_error, reason}], %{state | done?: true}}

      {ref, :done} when ref == state.ref ->
        {:halt, %{state | done?: true}}

      {:DOWN, monitor_ref, :process, pid, reason}
      when monitor_ref == state.worker_monitor_ref and pid == state.worker_pid ->
        handle_worker_down(state, reason)
    after
      state.receive_timeout ->
        {[:transport_timeout], %{state | done?: true}}
    end
  end

  defp handle_worker_down(state, :normal), do: {:halt, %{state | done?: true}}
  defp handle_worker_down(state, :shutdown), do: {:halt, %{state | done?: true}}
  defp handle_worker_down(state, {:shutdown, _reason}), do: {:halt, %{state | done?: true}}

  defp handle_worker_down(state, reason) do
    {[{:transport_error, {:worker_down, reason}}], %{state | done?: true}}
  end

  defp cleanup(%{worker_monitor_ref: monitor_ref, worker_pid: worker_pid}) do
    Process.demonitor(monitor_ref, [:flush])

    if is_pid(worker_pid) and Process.alive?(worker_pid) do
      Process.exit(worker_pid, :kill)
    end

    :ok
  end
end
