# credo:disable-for-this-file Credo.Check.Warning.StructFieldAmount

defmodule ExecutionPlane.Process.Transport.Subprocess.State do
  @moduledoc """
  Internal state schema for the subprocess transport coordinator.

  The GenServer is intentionally a coordinator. This module owns the state
  shape and groups fields by responsibility:

  * process identity and surface metadata;
  * subscriber/event delivery;
  * stdout/stderr framing and overflow recovery;
  * pending request tasks;
  * lifecycle timers and startup options;
  * stdin/stdout/interrupt runtime configuration.

  Phase 41 owns moving long-line spool file I/O behind its own boundary.
  """

  alias ExecutionPlane.{Command, LineFraming}
  alias ExecutionPlane.Process.OS
  alias ExecutionPlane.Process.Transport.Options

  defstruct subprocess: nil,
            invocation: nil,
            surface_kind: :local_subprocess,
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
            subscribers: %{},
            buffered_events: :queue.new(),
            buffered_event_count: 0,
            stdout_framer: %LineFraming{},
            pending_lines: :queue.new(),
            drain_scheduled?: false,
            status: :disconnected,
            stderr_buffer: "",
            stderr_framer: %LineFraming{},
            max_buffer_size: nil,
            oversize_line_chunk_bytes: nil,
            max_recoverable_line_bytes: nil,
            oversize_line_mode: :chunk_then_fail,
            buffer_overflow_mode: :fatal,
            long_line_spool: nil,
            max_stderr_buffer_size: nil,
            overflowed?: false,
            fatal_stop_scheduled?: false,
            pending_calls: %{},
            finalize_timer_ref: nil,
            headless_timeout_ms: nil,
            headless_timer_ref: nil,
            task_supervisor: nil,
            event_tag: nil,
            stdout_mode: :line,
            stdin_mode: :line,
            pty?: false,
            interrupt_mode: :signal,
            os: OS,
            stderr_callback: nil,
            replay_stderr_on_subscribe?: false,
            buffer_events_until_subscribe?: false,
            max_buffered_events: 128,
            startup_options: nil

  @doc false
  def new(%Options{} = options) do
    %__MODULE__{
      invocation: options.invocation_override || build_invocation(options),
      surface_kind: options.surface_kind,
      target_id: options.target_id,
      lease_ref: options.lease_ref,
      surface_ref: options.surface_ref,
      boundary_class: options.boundary_class,
      observability: options.observability,
      adapter_capabilities: options.adapter_capabilities,
      effective_capabilities: options.effective_capabilities,
      bridge_profile: options.bridge_profile,
      protocol_version: options.protocol_version,
      extensions: options.extensions,
      adapter_metadata: options.adapter_metadata,
      status: :disconnected,
      buffered_events: :queue.new(),
      buffered_event_count: 0,
      max_buffer_size: options.max_buffer_size,
      oversize_line_chunk_bytes: options.oversize_line_chunk_bytes,
      max_recoverable_line_bytes: options.max_recoverable_line_bytes,
      oversize_line_mode: options.oversize_line_mode,
      buffer_overflow_mode: options.buffer_overflow_mode,
      max_stderr_buffer_size: options.max_stderr_buffer_size,
      max_buffered_events: options.max_buffered_events,
      headless_timeout_ms: options.headless_timeout_ms,
      task_supervisor: options.task_supervisor,
      event_tag: options.event_tag,
      stdout_mode: options.stdout_mode,
      stdin_mode: options.stdin_mode,
      pty?: options.pty?,
      interrupt_mode: options.interrupt_mode,
      os: options.os,
      stderr_callback: options.stderr_callback,
      replay_stderr_on_subscribe?: options.replay_stderr_on_subscribe?,
      buffer_events_until_subscribe?: options.buffer_events_until_subscribe?,
      startup_options: options
    }
  end

  defp build_invocation(%Options{} = options) do
    Command.new(options.command, options.args,
      cwd: options.cwd,
      env: options.env,
      clear_env?: options.clear_env?,
      user: options.user
    )
  end
end
