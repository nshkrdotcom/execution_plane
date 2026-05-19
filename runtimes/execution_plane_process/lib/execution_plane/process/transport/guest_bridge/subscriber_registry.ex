defmodule ExecutionPlane.Process.Transport.GuestBridge.SubscriberRegistry do
  @moduledoc false

  @doc false
  def put(subscribers, pid, tag) when is_map(subscribers) and is_pid(pid) do
    subscriber_info = %{monitor_ref: Process.monitor(pid), tag: tag}
    Map.put(subscribers, pid, subscriber_info)
  end

  @doc false
  def drop(subscribers, pid) when is_map(subscribers) and is_pid(pid) do
    case Map.pop(subscribers, pid) do
      {nil, rest} ->
        rest

      {%{monitor_ref: ref}, rest} ->
        Process.demonitor(ref, [:flush])
        rest
    end
  end

  @doc false
  def handle_down(subscribers, ref, pid) when is_map(subscribers) do
    subscribers
    |> Enum.reject(fn {subscriber_pid, info} ->
      info.monitor_ref == ref or pid == subscriber_pid
    end)
    |> Map.new()
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
    Enum.each(subscribers, fn {pid, info} -> dispatch(pid, info, event, event_tag) end)
  end

  @doc false
  def buffer_event(events, count, max_events, event) do
    events =
      if count >= max_events do
        {_dropped, queue} = :queue.out(events)
        :queue.in(event, queue)
      else
        :queue.in(event, events)
      end

    {events, min(count + 1, max_events)}
  end
end
