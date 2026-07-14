# `ExecutionPlane.TaskSupport`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/task_support.ex#L1)

Small task helpers shared by the runtime and transport layers.

# `task_start_error`

```elixir
@type task_start_error() ::
  :noproc
  | {:runtime_not_started, :execution_plane_process}
  | {:task_start_failed, term()}
```

# `async_nolink`

```elixir
@spec async_nolink((-&gt; any())) :: {:ok, Task.t()} | {:error, task_start_error()}
```

Starts an unlinked task under the default task supervisor.

# `async_nolink`

```elixir
@spec async_nolink(pid() | atom(), (-&gt; any())) ::
  {:ok, Task.t()} | {:error, task_start_error()}
```

Starts an unlinked task under a specific task supervisor.

# `await`

```elixir
@spec await(Task.t(), timeout(), :brutal_kill | :shutdown) ::
  {:ok, term()} | {:exit, term()} | {:error, :timeout}
```

Awaits a task result using the `Task.yield || Task.shutdown` pattern.

# `start_child`

```elixir
@spec start_child((-&gt; any())) :: {:ok, pid()} | {:error, task_start_error()}
```

Starts a child task under the default task supervisor.

# `start_child`

```elixir
@spec start_child(pid() | atom(), (-&gt; any())) ::
  {:ok, pid()} | {:error, task_start_error()}
```

Starts a child task under a specific task supervisor.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
