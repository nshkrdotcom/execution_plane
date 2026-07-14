# `ExecutionPlane.Process.Transport.Options`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/options.ex#L2)

Normalized startup options for the raw transport layer.

# `subscriber`

```elixir
@type subscriber() ::
  pid()
  | {pid(), ExecutionPlane.Process.Transport.explicit_subscription_tag()}
  | nil
```

# `t`

```elixir
@type t() :: %ExecutionPlane.Process.Transport.Options{
  adapter_capabilities:
    ExecutionPlane.Process.Transport.Surface.Capabilities.t() | nil,
  adapter_metadata: map(),
  args: [String.t()],
  boundary_class: ExecutionPlane.Process.Transport.Surface.boundary_class(),
  bridge_profile: String.t() | nil,
  buffer_events_until_subscribe?: boolean(),
  buffer_overflow_mode: :fatal,
  clear_env?: boolean(),
  close_stdin_on_start?: boolean(),
  command: String.t(),
  cwd: String.t() | nil,
  effective_capabilities:
    ExecutionPlane.Process.Transport.Surface.Capabilities.t() | nil,
  env: ExecutionPlane.Command.env_map(),
  event_tag: atom(),
  extensions: map(),
  headless_timeout_ms: pos_integer() | :infinity,
  interrupt_mode: :signal | {:stdin, binary()},
  invocation_override: ExecutionPlane.Command.t() | nil,
  lease_ref: String.t() | nil,
  max_buffer_size: pos_integer(),
  max_buffered_events: pos_integer(),
  max_recoverable_line_bytes: pos_integer(),
  max_stderr_buffer_size: pos_integer(),
  observability: map(),
  os: module(),
  oversize_line_chunk_bytes: pos_integer(),
  oversize_line_mode: :chunk_then_fail,
  protocol_version: pos_integer() | nil,
  pty?: boolean(),
  replay_stderr_on_subscribe?: boolean(),
  startup_mode: :eager | :lazy,
  stderr_callback: (binary() -&gt; any()) | nil,
  stdin_mode: :line | :raw,
  stdout_mode: :line | :raw,
  subscriber: subscriber(),
  surface_kind: ExecutionPlane.Process.Transport.surface_kind(),
  surface_ref: String.t() | nil,
  target_id: String.t() | nil,
  task_supervisor: pid() | atom(),
  transport_options: keyword(),
  user: ExecutionPlane.Command.user()
}
```

# `validation_error`

```elixir
@type validation_error() ::
  :missing_command
  | {:invalid_surface_kind, term()}
  | {:invalid_target_id, term()}
  | {:invalid_lease_ref, term()}
  | {:invalid_surface_ref, term()}
  | {:invalid_boundary_class, term()}
  | {:invalid_observability, term()}
  | {:invalid_command, term()}
  | {:invalid_args, term()}
  | {:invalid_cwd, term()}
  | {:invalid_env, term()}
  | {:invalid_clear_env, term()}
  | {:invalid_user, term()}
  | {:invalid_stdout_mode, term()}
  | {:invalid_stdin_mode, term()}
  | {:invalid_pty, term()}
  | {:invalid_interrupt_mode, term()}
  | {:invalid_os, term()}
  | {:invalid_subscriber, term()}
  | {:invalid_startup_mode, term()}
  | {:invalid_task_supervisor, term()}
  | {:invalid_event_tag, term()}
  | {:invalid_headless_timeout_ms, term()}
  | {:invalid_max_buffer_size, term()}
  | {:invalid_oversize_line_chunk_bytes, term()}
  | {:invalid_max_recoverable_line_bytes, term()}
  | {:invalid_oversize_line_mode, term()}
  | {:invalid_buffer_overflow_mode, term()}
  | {:invalid_line_recovery_limits, term()}
  | {:invalid_max_stderr_buffer_size, term()}
  | {:invalid_max_buffered_events, term()}
  | {:invalid_stderr_callback, term()}
  | {:invalid_close_stdin_on_start, term()}
  | {:invalid_replay_stderr_on_subscribe, term()}
  | {:invalid_buffer_events_until_subscribe, term()}
  | {:invalid_bridge_profile, term()}
  | {:invalid_protocol_version, term()}
  | {:invalid_extensions, term()}
  | {:invalid_capabilities, term()}
```

# `new`

```elixir
@spec new(keyword()) ::
  {:ok, t()} | {:error, {:invalid_transport_options, validation_error()}}
```

Builds a validated transport options struct.

# `new!`

```elixir
@spec new!(keyword()) :: t()
```

Builds a validated transport options struct or raises.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
