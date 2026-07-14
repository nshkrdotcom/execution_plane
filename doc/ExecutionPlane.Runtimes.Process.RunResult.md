# `ExecutionPlane.Runtimes.Process.RunResult`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/runtimes/process/run_result.ex#L1)

Captured output and normalized exit data for one-shot process execution.

# `t`

```elixir
@type t() :: %ExecutionPlane.Runtimes.Process.RunResult{
  exit: ExecutionPlane.Runtimes.Process.Exit.t(),
  invocation: map(),
  output: binary(),
  stderr: binary(),
  stderr_mode: :separate | :stdout,
  stdout: binary()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
