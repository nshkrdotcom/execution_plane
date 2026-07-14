# `ExecutionPlane.Process.Transport.RunResult`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/run_result.ex#L1)

Captured output and normalized exit data for one-shot non-PTY execution.

# `stderr_mode`

```elixir
@type stderr_mode() :: :separate | :stdout
```

# `t`

```elixir
@type t() :: %ExecutionPlane.Process.Transport.RunResult{
  exit: ExecutionPlane.ProcessExit.t(),
  invocation: ExecutionPlane.Command.t(),
  output: binary(),
  stderr: binary(),
  stderr_mode: stderr_mode(),
  stdout: binary()
}
```

# `success?`

```elixir
@spec success?(t()) :: boolean()
```

Returns `true` when the captured execution completed successfully.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
