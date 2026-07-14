# `ExecutionPlane.Command`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/command.ex#L1)

Generic transport-level command invocation.

This struct stays below CLI-domain concerns. It only carries the executable,
argv, and launch-time process options needed by the execution-surface
substrate.

# `env_key`

```elixir
@type env_key() :: String.t()
```

# `env_map`

```elixir
@type env_map() :: %{optional(env_key()) =&gt; env_value()}
```

# `env_value`

```elixir
@type env_value() :: String.t()
```

# `t`

```elixir
@type t() :: %ExecutionPlane.Command{
  args: [String.t()],
  clear_env?: boolean(),
  command: String.t(),
  cwd: String.t() | nil,
  env: env_map(),
  user: user()
}
```

# `user`

```elixir
@type user() :: String.t() | nil
```

# `argv`

```elixir
@spec argv(t()) :: [String.t()]
```

Returns the executable and argv as a flat list.

# `merge_env`

```elixir
@spec merge_env(t(), map()) :: t()
```

Merges environment variables into the invocation.

# `new`

```elixir
@spec new(String.t(), [String.t()] | keyword(), keyword()) :: t()
```

Builds a normalized transport command.

# `put_env`

```elixir
@spec put_env(t(), String.t() | atom(), String.t() | atom() | number() | boolean()) ::
  t()
```

Adds or replaces one environment variable.

# `validate`

```elixir
@spec validate(t()) ::
  :ok
  | {:error, {:invalid_command, term()}}
  | {:error, {:invalid_args, term()}}
  | {:error, {:invalid_cwd, term()}}
  | {:error, {:invalid_env, term()}}
  | {:error, {:invalid_clear_env, term()}}
  | {:error, {:invalid_user, term()}}
```

Validates the generic transport command contract.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
