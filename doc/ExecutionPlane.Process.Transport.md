# `ExecutionPlane.Process.Transport`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport.ex#L1)

Behaviour for the raw subprocess transport layer.

In addition to the long-lived subscriber-driven transport API, the transport
layer also owns synchronous non-PTY command execution through `run/2`.

Subscribers receive tagged events only:

- `{event_tag, subscriber_pid, {:message, line}}` for `subscribe/2`
- `{event_tag, ref, {:message, line}}`
- `{event_tag, tag, {:data, chunk}}`
- `{event_tag, tag, {:error, %ExecutionPlane.Process.Transport.Error{}}}`
- `{event_tag, tag, {:stderr, chunk}}`
- `{event_tag, tag, {:exit, %ExecutionPlane.ProcessExit{}}}`

where `tag` is the subscriber pid when `subscribe/2` is used and an explicit
reference when `subscribe/3` is used.

When `:replay_stderr_on_subscribe?` is enabled at startup, newly attached
subscribers also receive the retained stderr tail immediately after
subscription. When `:buffer_events_until_subscribe?` is enabled, stdout,
stderr, and error events emitted before the first subscriber attaches are
replayed in order.

# `event_tag`

```elixir
@type event_tag() :: atom()
```

The tagged event atom prefix.

# `explicit_subscription_tag`

```elixir
@type explicit_subscription_tag() :: reference()
```

Caller-supplied tag for explicit subscriptions.

# `extracted_event`

```elixir
@type extracted_event() ::
  {:message, binary()}
  | {:data, binary()}
  | {:error, ExecutionPlane.Process.Transport.Error.t()}
  | {:stderr, binary()}
  | {:exit, ExecutionPlane.ProcessExit.t()}
```

Normalized transport event payload extracted from a mailbox message.

# `message`

```elixir
@type message() :: {event_tag(), subscription_tag(), extracted_event()}
```

Transport events delivered to subscribers.

# `subscription_tag`

```elixir
@type subscription_tag() :: pid() | reference()
```

Mailbox tag carried on tagged delivery.

# `surface_kind`

```elixir
@type surface_kind() ::
  :local_subprocess | :ssh_exec | :guest_bridge | :lower_simulation
```

Generic execution-surface placement kind.

# `t`

```elixir
@type t() :: pid()
```

Opaque transport reference.

# `close`

```elixir
@callback close(t()) :: :ok
```

# `end_input`

```elixir
@callback end_input(t()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

# `force_close`

```elixir
@callback force_close(t()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

# `info`

```elixir
@callback info(t()) :: ExecutionPlane.Process.Transport.Info.t()
```

# `interrupt`

```elixir
@callback interrupt(t()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

# `run`

```elixir
@callback run(
  ExecutionPlane.Command.t(),
  keyword()
) ::
  {:ok, ExecutionPlane.Process.Transport.RunResult.t()}
  | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

# `send`

```elixir
@callback send(t(), iodata() | map() | list()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

# `start`

```elixir
@callback start(keyword()) ::
  {:ok, t()}
  | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

# `start_link`

```elixir
@callback start_link(keyword()) ::
  {:ok, t()}
  | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

# `status`

```elixir
@callback status(t()) :: :connected | :disconnected | :error
```

# `stderr`

```elixir
@callback stderr(t()) :: binary()
```

# `subscribe`

```elixir
@callback subscribe(t(), pid()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

# `subscribe`

```elixir
@callback subscribe(t(), pid(), explicit_subscription_tag()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

# `unsubscribe`

```elixir
@callback unsubscribe(t(), pid()) :: :ok
```

# `close`

```elixir
@spec close(t()) :: :ok
```

Stops the transport.

# `delivery_info`

```elixir
@spec delivery_info(t()) :: ExecutionPlane.Process.Transport.Delivery.t()
```

Returns stable mailbox-delivery metadata for the current transport snapshot.

# `end_input`

```elixir
@spec end_input(t()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

Closes stdin for EOF-driven CLIs.

Pipe-backed transports send `:eof`; PTY-backed transports send the terminal
EOF byte (`Ctrl-D`).

# `extract_event`

```elixir
@spec extract_event(term()) :: {:ok, extracted_event()} | :error
```

Extracts a normalized transport event from a tagged mailbox message.

# `extract_event`

```elixir
@spec extract_event(term(), subscription_tag()) :: {:ok, extracted_event()} | :error
```

Extracts a normalized transport event for a matching subscriber tag.

This is the stable core-owned way for adapters to consume tagged transport
delivery without hard-coding the configured outer event atom.

# `force_close`

```elixir
@spec force_close(t()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

Forces the subprocess down immediately.

# `info`

```elixir
@spec info(t()) :: ExecutionPlane.Process.Transport.Info.t()
```

Returns the current transport metadata snapshot.

# `interrupt`

```elixir
@spec interrupt(t()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

Sends SIGINT to the subprocess.

# `run`

```elixir
@spec run(
  ExecutionPlane.Command.t(),
  keyword()
) ::
  {:ok, ExecutionPlane.Process.Transport.RunResult.t()}
  | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

Runs a one-shot non-PTY command and captures exact stdout, stderr, and exit
data.

# `send`

```elixir
@spec send(t(), iodata() | map() | list()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

Sends data to the subprocess stdin.

# `start`

```elixir
@spec start(keyword()) ::
  {:ok, t()}
  | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

Starts the default raw transport implementation.

# `start_link`

```elixir
@spec start_link(keyword()) ::
  {:ok, t()}
  | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

Starts the default raw transport implementation and links it to the caller.

# `status`

```elixir
@spec status(t()) :: :connected | :disconnected | :error
```

Returns transport connectivity status.

# `stderr`

```elixir
@spec stderr(t()) :: binary()
```

Returns the stderr ring buffer tail.

# `subscribe`

```elixir
@spec subscribe(t(), pid()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

Subscribes a process using the subscriber pid as the default mailbox tag.

# `subscribe`

```elixir
@spec subscribe(t(), pid(), explicit_subscription_tag()) ::
  :ok | {:error, {:transport, ExecutionPlane.Process.Transport.Error.t()}}
```

Subscribes a process with an explicit reference tag.

# `unsubscribe`

```elixir
@spec unsubscribe(t(), pid()) :: :ok
```

Removes a subscriber.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
