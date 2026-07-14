# `ExecutionPlane.Process.Transport.RunOptions`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/run_options.ex#L1)

Validated options for synchronous non-PTY command execution.

# `stderr_mode`

```elixir
@type stderr_mode() :: :separate | :stdout
```

# `t`

```elixir
@type t() :: %ExecutionPlane.Process.Transport.RunOptions{
  close_stdin: boolean(),
  command: ExecutionPlane.Command.t(),
  os: module(),
  stderr: stderr_mode(),
  stdin: term(),
  timeout: timeout()
}
```

# `validation_error`

```elixir
@type validation_error() ::
  {:invalid_command, term()}
  | {:invalid_args, term()}
  | {:invalid_cwd, term()}
  | {:invalid_env, term()}
  | {:invalid_clear_env, term()}
  | {:invalid_user, term()}
  | {:invalid_timeout, term()}
  | {:invalid_stderr, term()}
  | {:invalid_close_stdin, term()}
  | {:invalid_os, term()}
```

# `default_timeout_ms`

```elixir
@spec default_timeout_ms() :: 30000
```

Returns the default synchronous command timeout in milliseconds.

# `new`

```elixir
@spec new(
  ExecutionPlane.Command.t(),
  keyword()
) :: {:ok, t()} | {:error, {:invalid_run_options, validation_error()}}
```

Builds validated run options for the raw transport command lane.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
