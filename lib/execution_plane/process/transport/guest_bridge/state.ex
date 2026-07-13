# credo:disable-for-this-file Credo.Check.Warning.StructFieldAmount

defmodule ExecutionPlane.Process.Transport.GuestBridge.State do
  @moduledoc """
  Internal state schema for the guest bridge transport coordinator.

  The GenServer owns callback sequencing. This module owns the state shape for
  socket identity, stream framing, subscribers, and request tracking.

  Phase 42 caps this state schema at 32 fields. Any future field addition must
  either remove an existing field or introduce a narrower nested state owner.
  """

  alias ExecutionPlane.{Command, LineFraming}
  alias ExecutionPlane.Process.Transport.Options
  alias ExecutionPlane.Process.Transport.Surface.Capabilities

  @surface_kind :guest_bridge

  defstruct socket: nil,
            buffer: "",
            invocation: nil,
            surface_kind: @surface_kind,
            transport_options: [],
            target_id: nil,
            lease_ref: nil,
            surface_ref: nil,
            boundary_class: nil,
            observability: %{},
            adapter_capabilities: nil,
            effective_capabilities: nil,
            bridge_profile: nil,
            protocol_version: nil,
            extensions: %{},
            adapter_metadata: %{},
            status: :disconnected,
            stdout_mode: :line,
            stdin_mode: :line,
            pty?: false,
            interrupt_mode: :signal,
            stderr_buffer: "",
            stdout_framer: %LineFraming{},
            subscribers: %{},
            event_tag: :execution_plane_process,
            replay_stderr_on_subscribe?: false,
            buffer_events_until_subscribe?: false,
            buffered_events: :queue.new(),
            buffered_event_count: 0,
            max_buffered_events: 128,
            pending_requests: %{},
            request_seq: 0

  @doc false
  def new(%Options{} = options, %Capabilities{} = adapter_capabilities) do
    %__MODULE__{
      invocation: invocation(options),
      transport_options: options.transport_options,
      target_id: options.target_id,
      lease_ref: options.lease_ref,
      surface_ref: options.surface_ref,
      boundary_class: options.boundary_class,
      observability: options.observability,
      adapter_capabilities: adapter_capabilities,
      status: :disconnected,
      stdout_mode: options.stdout_mode,
      stdin_mode: options.stdin_mode,
      pty?: options.pty?,
      interrupt_mode: options.interrupt_mode,
      event_tag: options.event_tag,
      replay_stderr_on_subscribe?: options.replay_stderr_on_subscribe?,
      buffer_events_until_subscribe?: options.buffer_events_until_subscribe?,
      max_buffered_events: options.max_buffered_events,
      adapter_metadata: %{
        endpoint: Keyword.get(options.transport_options, :endpoint),
        bridge_ref: Keyword.get(options.transport_options, :bridge_ref)
      }
    }
  end

  @doc false
  def invocation(%Options{} = options) do
    options.invocation_override ||
      Command.new(options.command, options.args,
        cwd: options.cwd,
        env: options.env,
        clear_env?: options.clear_env?,
        user: options.user
      )
  end
end
