# `ExecutionPlane.Process.Transport.Error`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/error.ex#L1)

Structured transport error with a normalized reason and debugging context.

# `reason`

```elixir
@type reason() ::
  :not_connected
  | :timeout
  | :transport_stopped
  | {:unsupported_capability, atom(), atom()}
  | {:bridge_protocol_error, term()}
  | {:bridge_remote_error, term(), term()}
  | {:buffer_overflow, pos_integer(), pos_integer()}
  | {:send_failed, term()}
  | {:call_exit, term()}
  | {:command_not_found, String.t() | atom()}
  | {:cwd_not_found, String.t()}
  | {:invalid_options, term()}
  | {:startup_failed, term()}
  | term()
```

# `t`

```elixir
@type t() :: %ExecutionPlane.Process.Transport.Error{
  __exception__: true,
  context: map(),
  message: String.t(),
  reason: reason()
}
```

# `bridge_protocol_error`

```elixir
@spec bridge_protocol_error(term()) :: t()
```

Builds a bridge-protocol error.

# `bridge_remote_error`

```elixir
@spec bridge_remote_error(term(), term()) :: t()
```

Builds a bridge-remote error.

# `buffer_overflow`

```elixir
@spec buffer_overflow(pos_integer(), pos_integer(), binary(), map()) :: t()
```

Builds a buffer overflow error with preview metadata.

# `call_exit`

```elixir
@spec call_exit(term()) :: t()
```

Builds a call-exit error.

# `command_not_found`

```elixir
@spec command_not_found(String.t() | atom(), term()) :: t()
```

Builds a command-not-found error.

# `cwd_not_found`

```elixir
@spec cwd_not_found(String.t()) :: t()
```

Builds a cwd-not-found error.

# `invalid_options`

```elixir
@spec invalid_options(term()) :: t()
```

Builds an invalid-options error.

# `not_connected`

```elixir
@spec not_connected() :: t()
```

Builds a not-connected error.

# `send_failed`

```elixir
@spec send_failed(term()) :: t()
```

Builds a send failure error.

# `startup_failed`

```elixir
@spec startup_failed(term()) :: t()
```

Builds a startup-failed error.

# `timeout`

```elixir
@spec timeout() :: t()
```

Builds a timeout error.

# `transport_error`

```elixir
@spec transport_error(reason(), map()) :: t()
```

Builds a generic transport error.

# `transport_stopped`

```elixir
@spec transport_stopped() :: t()
```

Builds a transport-stopped error.

# `unsupported_capability`

```elixir
@spec unsupported_capability(atom(), atom()) :: t()
```

Builds an unsupported-capability error.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
