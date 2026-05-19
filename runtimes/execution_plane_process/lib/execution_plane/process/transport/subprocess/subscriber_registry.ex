defmodule ExecutionPlane.Process.Transport.Subprocess.SubscriberRegistry do
  @moduledoc false

  @doc false
  def put(subscribers, pid, tag) when is_map(subscribers) and is_pid(pid) do
    case Map.fetch(subscribers, pid) do
      {:ok, %{monitor_ref: monitor_ref}} ->
        Map.put(subscribers, pid, %{monitor_ref: monitor_ref, tag: tag})

      :error ->
        monitor_ref = Process.monitor(pid)
        Map.put(subscribers, pid, %{monitor_ref: monitor_ref, tag: tag})
    end
  end

  @doc false
  def remove(subscribers, pid) when is_map(subscribers) and is_pid(pid) do
    case Map.pop(subscribers, pid) do
      {nil, rest} ->
        {nil, rest}

      {%{monitor_ref: monitor_ref}, rest} ->
        Process.demonitor(monitor_ref, [:flush])
        {monitor_ref, rest}
    end
  end

  @doc false
  def handle_down(subscribers, ref, pid) when is_map(subscribers) do
    case Map.pop(subscribers, pid) do
      {%{monitor_ref: ^ref}, rest} -> rest
      {_value, rest} -> rest
    end
  end

  @doc false
  def demonitor(subscribers) when is_map(subscribers) do
    Enum.each(subscribers, fn {_pid, %{monitor_ref: ref}} ->
      Process.demonitor(ref, [:flush])
    end)
  end

  @doc false
  def dispatch(pid, %{tag: tag}, event, event_tag)
      when (is_pid(tag) or is_reference(tag)) and is_atom(event_tag) do
    Kernel.send(pid, {event_tag, tag, event})
  end

  @doc false
  def send_event(subscribers, event, event_tag) when is_map(subscribers) do
    Enum.each(subscribers, fn {pid, info} ->
      dispatch(pid, info, event, event_tag)
    end)
  end

  @doc false
  def buffer_event(events, count, max_events, event) do
    events = :queue.in(event, events)
    count = count + 1

    if count > max_events do
      {{:value, _dropped}, events} = :queue.out(events)
      {events, count - 1}
    else
      {events, count}
    end
  end
end
